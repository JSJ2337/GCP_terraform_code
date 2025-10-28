#!/bin/bash
set -euo pipefail

#!/usr/bin/env bash
set -euo pipefail

#!/usr/bin/env bash
# ---------- 사용자 설정 ----------
HOST_PREFIX="rag-api-pub"
# PAD=2 # 이 줄은 더 이상 필요 없습니다.
TAG_KEY="Name"
LOG=/var/log/hostname-init.log

# 새로운 설정 변수: 숫자의 시작 오프셋 (0: 01부터 시작, 10: 11부터 시작)
START_INDEX_OFFSET=0 # 0으로 설정하면 01, 02, ... 로 시작합니다.
                     # 10으로 설정하면 11, 12, ... 로 시작합니다.
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

# 2) AWS CLI (있으면 스킵)
command -v aws >/dev/null 2>&1 || yum -q -y install awscli

# 3) ASG 이름
ASG=$(aws autoscaling describe-auto-scaling-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'AutoScalingInstances[0].AutoScalingGroupName' \
        --output text --region "$REGION")

# 4) 같은 ASG 인스턴스 ID 사전식 정렬
IDS=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG" \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
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

NAME="${HOST_PREFIX}${NUM}"

# 6) 이미 같은 Name 태그가 있으면 숫자 하나 올림(충돌 방지)
while aws ec2 describe-instances \
        --filters "Name=tag:${TAG_KEY},Values=${NAME}" \
        --region "$REGION" --query "Reservations[].Instances[].InstanceId" \
        --output text | grep -qv "^$" ; do
    ((idx++))

    # 충돌 시에도 숫자의 시작 오프셋을 적용한 실제 호스트네임 숫자 다시 계산
    current_hostname_number=$((idx + START_INDEX_OFFSET))

    # START_INDEX_OFFSET 값에 따라 0-패딩 여부 다시 결정
    if [[ "$START_INDEX_OFFSET" -eq 0 ]]; then
      NUM=$(printf "%02d" "$current_hostname_number")
    else
      NUM=$(printf "%d" "$current_hostname_number")
    nfi
    NAME="${HOST_PREFIX}${NUM}"
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
  x86_64) RPM_ARCH="x86_64"; DEB_ARCH="amd64";; \
  aarch64) RPM_ARCH="arm64"; DEB_ARCH="arm64";; \
  *) echo "Unsupported arch: ${MACHINE}" >&2; exit 1;; \
esac

# 2) 리전 감지 (EC2 메타데이터)
REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/region)"

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
