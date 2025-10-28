#!/bin/bash
set -euo pipefail

# ---------- 사용자 설정 ----------
HOST_PREFIX="rag-lobby"
TAG_KEY="Name"
LOG=/var/log/hostname-init.log

# 새로운 설정 변수: 숫자의 시작 오프셋 (0: 01부터 시작, 10: 11부터 시작)
START_INDEX_OFFSET=10 # 0으로 설정하면 01, 02, ... 로 시작합니다.
                     # 10으로 설정하면 11, 12, ... 로 시작합니다.
MAX_WAIT_TIME=120    # ASG 순서 기반 호스트명 대기 최대 시간 (초, 기본 2분)
WAIT_INTERVAL=5      # 호스트명 사용 가능 여부 체크 간격 (초)
MAX_RETRY_COUNT=20   # 폴백 시 순차 할당 최대 재시도 횟수
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
        --output text --region "$REGION") || { echo "ERROR: Failed to get ASG name" >&2; exit 1; }

[[ "$ASG" == "None" || -z "$ASG" ]] && { echo "ERROR: Instance not in ASG" >&2; exit 1; }

# 4) 같은 ASG 활성 인스턴스 ID 사전식 정렬 (terminated 제외)
IDS=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG" \
        --query 'AutoScalingGroups[0].Instances[?LifecycleState!=`Terminated`].InstanceId' \
        --output text --region "$REGION" | tr '\t' '\n' | sort) || { echo "ERROR: Failed to get ASG instances" >&2; exit 1; }

[[ -z "$IDS" ]] && { echo "ERROR: No instances found in ASG" >&2; exit 1; }

# 5) 내 인덱스 구하기
idx=1
for id in $IDS; do
  [[ "$id" == "$INSTANCE_ID" ]] && break
  ((idx++))
done


# 6) 개선된 호스트명 할당: ASG 순서 기반 고정 번호 + 대기 방식
# 레이스 컨디션 방지를 위한 랜덤 지연 (0.5-2.5초)
sleep_time=$((5 + RANDOM % 20))  # 0.5초 단위로 0.5-2.5초
if command -v bc >/dev/null 2>&1; then
    sleep $(echo "scale=1; $sleep_time/10" | bc)
else
    echo "WARNING: bc not found, using 1 second delay instead of calculated random delay"
    sleep 1
fi

# ASG 내 고정된 순서 기반 번호 계산 (변경하지 않음)
fixed_hostname_number=$((idx + START_INDEX_OFFSET))
if [[ "$START_INDEX_OFFSET" -eq 0 ]]; then
    FIXED_NUM=$(printf "%02d" "$fixed_hostname_number")
else
    FIXED_NUM=$(printf "%d" "$fixed_hostname_number")
fi
DESIRED_NAME="${HOST_PREFIX}${FIXED_NUM}"

echo "Trying to assign hostname based on ASG position: $DESIRED_NAME (position $idx)"

# 원하는 번호가 사용 중이면 대기 후 재시도
total_waited=0

while [[ $total_waited -lt $MAX_WAIT_TIME ]]; do
    existing_instances=$(aws ec2 describe-instances \
        --filters "Name=tag:${TAG_KEY},Values=${DESIRED_NAME}" \
                 "Name=instance-state-name,Values=running,pending" \
        --region "$REGION" \
        --query "Reservations[].Instances[?InstanceId!=\`${INSTANCE_ID}\`].InstanceId" \
        --output text)

    if [[ -z "$existing_instances" || "$existing_instances" == "None" ]]; then
        NAME="$DESIRED_NAME"
        echo "Successfully assigned desired hostname: $NAME"
        break
    fi

    echo "Waiting for hostname $DESIRED_NAME to become available... (${total_waited}s/${MAX_WAIT_TIME}s)"
    sleep $WAIT_INTERVAL
    ((total_waited += WAIT_INTERVAL))
done

# 대기 시간 초과 시 순차 증가 방식으로 폴백
if [[ $total_waited -ge $MAX_WAIT_TIME ]]; then
    echo "Timeout waiting for desired hostname. Trying sequential assignment..."

    # 순차 증가 방식 폴백
    current_try_number=$((idx + START_INDEX_OFFSET))
    retry_count=0

    while [[ $retry_count -lt $MAX_RETRY_COUNT ]]; do
        if [[ "$START_INDEX_OFFSET" -eq 0 ]]; then
            NUM=$(printf "%02d" "$current_try_number")
        else
            NUM=$(printf "%d" "$current_try_number")
        fi
        NAME="${HOST_PREFIX}${NUM}"

        # 이미 사용 중인지 확인 (자기 자신 제외)
        existing_instances=$(aws ec2 describe-instances \
            --filters "Name=tag:${TAG_KEY},Values=${NAME}" \
                     "Name=instance-state-name,Values=running,pending" \
            --region "$REGION" \
            --query "Reservations[].Instances[?InstanceId!=\`${INSTANCE_ID}\`].InstanceId" \
            --output text)

        # 사용 가능한 호스트명이면 종료
        if [[ -z "$existing_instances" || "$existing_instances" == "None" ]]; then
            echo "Selected fallback hostname: $NAME (attempt $((retry_count + 1)))"
            break
        fi

        echo "Hostname $NAME already exists, trying next number... (attempt $((retry_count + 1))/$MAX_RETRY_COUNT)"
        ((current_try_number++))
        ((retry_count++))
        sleep 1
    done

    # 최종 폴백: 타임스탬프 기반
    if [[ $retry_count -ge $MAX_RETRY_COUNT ]]; then
        echo "ERROR: All sequential attempts failed. Using timestamp-based fallback." >&2
        TIMESTAMP=$(date +%s)
        NAME="${HOST_PREFIX}${TIMESTAMP: -3}"
        echo "Final fallback hostname: $NAME"
    fi
fi

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
    echo "Installing SSM agent via yum..."
    yum install -y amazon-ssm-agent || { echo "ERROR: Failed to install SSM agent via yum" >&2; return 1; }
  elif command -v dnf >/dev/null 2>&1; then
    echo "Installing SSM agent via dnf..."
    dnf install -y amazon-ssm-agent || { echo "ERROR: Failed to install SSM agent via dnf" >&2; return 1; }
  elif command -v apt-get >/dev/null 2>&1; then
    echo "Installing SSM agent via apt-get..."
    apt-get update || { echo "ERROR: Failed to update package list" >&2; return 1; }
    apt-get install -y amazon-ssm-agent || { echo "ERROR: Failed to install SSM agent via apt-get" >&2; return 1; }
  else
    echo "ERROR: No supported package manager found" >&2
    return 1
  fi
}

install_manual_rpm() {
  echo "Installing SSM agent via manual RPM download..."
  local url="https://s3.${REGION}.amazonaws.com/amazon-ssm-${REGION}/latest/${RPM_ARCH}/amazon-ssm-agent.rpm"
  curl -sSL "${url}" -o /tmp/amazon-ssm-agent.rpm || { echo "ERROR: Failed to download SSM agent RPM from ${url}" >&2; return 1; }
  rpm -Uvh /tmp/amazon-ssm-agent.rpm || { echo "ERROR: Failed to install SSM agent RPM" >&2; return 1; }
  echo "SSM agent RPM installed successfully"
}

install_manual_deb() {
  echo "Installing SSM agent via manual DEB download..."
  local url="https://s3.${REGION}.amazonaws.com/amazon-ssm-${REGION}/latest/debian_${DEB_ARCH}/amazon-ssm-agent.deb"
  curl -sSL "${url}" -o /tmp/amazon-ssm-agent.deb || { echo "ERROR: Failed to download SSM agent DEB from ${url}" >&2; return 1; }
  if ! dpkg -i /tmp/amazon-ssm-agent.deb; then
    echo "WARNING: dpkg failed, trying to fix dependencies..."
    apt-get install -f -y || { echo "ERROR: Failed to fix dependencies and install SSM agent DEB" >&2; return 1; }
  fi
  echo "SSM agent DEB installed successfully"
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
echo "Enabling and starting SSM agent service..."
systemctl enable amazon-ssm-agent --now || { echo "ERROR: Failed to enable/start SSM agent service" >&2; exit 1; }
echo "SSM agent service enabled and started successfully"
