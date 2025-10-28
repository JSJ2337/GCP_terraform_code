#!/bin/bash
set -euo pipefail


# ─── ❶ 호스트네임 설정 시작 ───

# ==== 사용자 설정 ====
HOST_PREFIX="ftt-lgtm-prd"   # 접두사
PAD=2                       # 01,02…
TAG_KEY="Name"              # 콘솔 컬럼
# =====================

# IMDSv2 토큰
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
imds() { curl -s -H "X-aws-ec2-metadata-token:$TOKEN" \
               "http://169.254.169.254/latest/meta-data/$1"; }

INSTANCE_ID=$(imds instance-id)
REGION=$(imds placement/region)

# AWS CLI 확보(이미 설치돼 있으면 스킵)
command -v aws >/dev/null 2>&1 || yum -q -y install awscli

# ASG 이름
ASG=$(aws autoscaling describe-auto-scaling-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'AutoScalingInstances[0].AutoScalingGroupName' \
        --output text --region "$REGION")

# 사전식 정렬 후 순번
idx=1
for id in $(aws autoscaling describe-auto-scaling-groups \
              --auto-scaling-group-names "$ASG" \
              --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
              --output text --region "$REGION" | tr '\t' '\n' | sort); do
  [[ "$id" == "$INSTANCE_ID" ]] && break
  ((idx++))
done
NUM=$(printf "%0${PAD}d" "$idx")
NAME="${HOST_PREFIX}${NUM}"

hostnamectl set-hostname "$NAME"
echo "127.0.0.1 $NAME" >> /etc/hosts

aws ec2 create-tags \
  --resources "$INSTANCE_ID" \
  --tags "Key=${TAG_KEY},Value=${NAME}" \
  --region "$REGION"

# ─── ❶ 호스트네임 설정 끝 ───

# 1) 아키텍처 감지
MACHINE="$(uname -m)"
case "${MACHINE}" in
  x86_64) RPM_ARCH="x86_64"; DEB_ARCH="amd64";;
  aarch64) RPM_ARCH="arm64"; DEB_ARCH="arm64";;
  *) echo "Unsupported arch: ${MACHINE}" >&2; exit 1;;
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
