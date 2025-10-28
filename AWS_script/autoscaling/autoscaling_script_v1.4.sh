#!/bin/bash
set -euo pipefail

# autoscaling_script_v1.4.sh - 개선된 호스트네임 설정 및 SSM 에이전트 설치  
# 변경사항: ASG 순서 기반 순차 할당, terminated 인스턴스 제외, 충돌 검사 제거로 안정성 향상

# ---------- 사용자 설정 ----------
HOST_PREFIX="rag-lobby"
TAG_KEY="Name"
LOG=/var/log/hostname-init.log

# 새로운 설정 변수: 숫자의 시작 오프셋 (0: 01부터 시작, 10: 11부터 시작)
START_INDEX_OFFSET=10 # 0으로 설정하면 01, 02, ... 로 시작합니다.
                     # 10으로 설정하면 11, 12, ... 로 시작합니다.
MAX_RETRY_COUNT=20   # 호스트명 충돌 시 최대 재시도 횟수 (다시 활성화)
# ---------------------------------

exec >>"$LOG" 2>&1    # 실패해도 전체 로그 확인 가능
echo "---- $(date '+%F %T') ----"

# 1) IMDSv2
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
        -H "X-aws-ec2-metadata-token-ttl-seconds:21600") || exit 1
imds() { curl -s -H "X-aws-ec2-metadata-token:$TOKEN" \
               "http://169.254.169.254/latest/meta-data/$1"; }

INSTANCE_ID=$(imds instance-id)
REGION=$(imds placement/region)

# 2) AWS CLI (있으면 스킵, 설치 실패 시 에러 처리)
if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI not found, installing..."
    if command -v yum >/dev/null 2>&1; then
        yum -q -y install awscli || { echo "ERROR: Failed to install AWS CLI via yum" >&2; exit 1; }
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y awscli || { echo "ERROR: Failed to install AWS CLI via apt-get" >&2; exit 1; }
    else
        echo "ERROR: No package manager found to install AWS CLI" >&2
        exit 1
    fi
fi

# 3) ASG 이름
ASG=$(aws autoscaling describe-auto-scaling-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'AutoScalingInstances[0].AutoScalingGroupName' \
        --output text --region "$REGION")

# 4) 같은 ASG 활성 인스턴스 ID 사전식 정렬 (terminated 제외)
IDS=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG" \
        --query 'AutoScalingGroups[0].Instances[?LifecycleState!=`Terminated`].InstanceId' \
        --output text --region "$REGION" | tr '\t' '\n' | sort)

# 5) 내 인덱스 구하기
idx=1
for id in $IDS; do
  [[ "$id" == "$INSTANCE_ID" ]] && break
  ((idx++))
done

# 숫자의 시작 오프셋을 적용한 실제 호스트네임 숫자 계산
current_hostname_number=$((idx + START_INDEX_OFFSET))

# START_INDEX_OFFSET 값에 따라 0-패딩 여부 결정
if [[ "$START_INDEX_OFFSET" -eq 0 ]]; then
  # 0부터 시작하는 경우 (예: 01, 02, ...)
  NUM=$(printf "%02d" "$current_hostname_number")
else
  # 다른 숫자부터 시작하는 경우 (예: 11, 12, ...)
  NUM=$(printf "%d" "$current_hostname_number")
fi

# NAME="${HOST_PREFIX}${NUM}"  # 이제 while 루프에서 동적으로 생성

# 6) 개선된 호스트명 할당: ASG 순서 기반 + 충돌 방지
retry_count=0
# 레이스 컨디션 방지를 위한 랜덤 지연 (0.5-2.5초)
sleep_time=$((5 + RANDOM % 20))  # 0.5초 단위로 0.5-2.5초
sleep $(echo "scale=1; $sleep_time/10" | bc 2>/dev/null || echo "1")

while true; do
    # 현재 시도할 호스트명 생성
    current_hostname_number=$((idx + START_INDEX_OFFSET))
    if [[ "$START_INDEX_OFFSET" -eq 0 ]]; then
        NUM=$(printf "%02d" "$current_hostname_number")
    else
        NUM=$(printf "%d" "$current_hostname_number")
    fi
    NAME="${HOST_PREFIX}${NUM}"
    
    # 이미 사용 중인지 확인 (자기 자신 제외)
    existing_instances=$(aws ec2 describe-instances \
        --filters "Name=tag:${TAG_KEY},Values=${NAME}" \
                 "Name=instance-state-name,Values=running,pending,shutting-down,stopping" \
        --region "$REGION" \
        --query "Reservations[].Instances[?InstanceId!=\`${INSTANCE_ID}\`].InstanceId" \
        --output text)
    
    # 사용 가능한 호스트명이면 종료
    if [[ -z "$existing_instances" || "$existing_instances" == "None" ]]; then
        echo "Selected hostname: $NAME (attempt $((retry_count + 1)))"
        break
    fi
    
    # 무한루프 방지
    if [[ $retry_count -ge $MAX_RETRY_COUNT ]]; then
        echo "ERROR: Maximum retry count ($MAX_RETRY_COUNT) exceeded. Using fallback hostname." >&2
        # 타임스탬프 기반 폴백
        TIMESTAMP=$(date +%s)
        NAME="${HOST_PREFIX}${TIMESTAMP: -3}"
        echo "Fallback hostname: $NAME"
        break
    fi
    
    echo "Hostname $NAME already exists, trying next number... (attempt $((retry_count + 1))/$MAX_RETRY_COUNT)"
    ((idx++))
    ((retry_count++))
    sleep 1  # 짧은 지연
done

# 7) 호스트네임 및 /etc/hosts
hostnamectl set-hostname "$NAME"
grep -qE "\s${NAME}(\s|$)" /etc/hosts || echo "127.0.0.1 $NAME" >> /etc/hosts

# 8) 태그 반영(이미 있으면 덮어쓰기)
aws ec2 create-tags \
  --resources "$INSTANCE_ID" \
  --tags "Key=${TAG_KEY},Value=${NAME}" \
  --region "$REGION"

echo "SET OK → $NAME"


# ─── ❶ 호스트네임 설정 끝 ───

# 1) 아키텍처 감지
MACHINE="$(uname -m)"
case "${MACHINE}" in
  x86_64) RPM_ARCH="x86_64"; DEB_ARCH="amd64";;
  aarch64) RPM_ARCH="arm64"; DEB_ARCH="arm64";;
  *) echo "Unsupported arch: ${MACHINE}" >&2; exit 1;;
esac

# 2) 리전 재사용 (이미 위에서 조회함)

# 3) OS 감지
. /etc/os-release
OS_ID="${ID}"

install_via_repo() {
  # yum/dnf/apt로 바로 설치
  if command -v yum >/dev/null 2>&1; then
    yum install -y amazon-ssm-agent
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y amazon-ssm-agent
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y amazon-ssm-agent
  else
    return 1
  fi
}

install_manual_rpm() {
  local url="https://s3.${REGION}.amazonaws.com/amazon-ssm-${REGION}/latest/${RPM_ARCH}/amazon-ssm-agent.rpm"
  curl -sSL "${url}" -o /tmp/amazon-ssm-agent.rpm
  rpm -Uvh /tmp/amazon-ssm-agent.rpm
}

install_manual_deb() {
  local url="https://s3.${REGION}.amazonaws.com/amazon-ssm-${REGION}/latest/debian_${DEB_ARCH}/amazon-ssm-agent.deb"
  curl -sSL "${url}" -o /tmp/amazon-ssm-agent.deb
  dpkg -i /tmp/amazon-ssm-agent.deb || apt-get install -f -y
}

case "${OS_ID}" in
  amzn|amzn2|amazon|al2023|centos|rhel)
    # RPM 계열
    if ! install_via_repo; then
      install_manual_rpm
    fi
    ;;
  ubuntu|debian)
    # DEB 계열
    if ! install_via_repo; then
      install_manual_deb
    fi
    ;;
  *)
    echo "SSM Agent 설치 불가: 지원되지 않는 OS ${OS_ID}" >&2
    exit 1
    ;;
esac

# 4) 서비스 활성화
systemctl enable amazon-ssm-agent --now
