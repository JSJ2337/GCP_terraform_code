#!/bin/bash
set -eux

# ─── ❶ 호스트네임 설정 시작 ───

# 메타데이터에서 인스턴스 ID 조회
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# 이 인스턴스가 속한 Auto Scaling Group 이름 조회
ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
  --instance-ids "${INSTANCE_ID}" \
  --query 'AutoScalingInstances[0].AutoScalingGroupName' --output text)

# 해당 ASG의 모든 인스턴스 ID 리스트를 가져와 정렬
INSTANCES=( $(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${ASG_NAME}" \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text | tr ' ' '\n' | sort) )

# 내 인스턴스가 배열의 몇 번째인지(0 베이스) 찾아서 +1
for idx in "${!INSTANCES[@]}"; do
  if [[ "${INSTANCES[$idx]}" == "${INSTANCE_ID}" ]]; then
    SEQ=$((idx + 1))
    break
  fi
done

# 2자리 제로패딩 (01, 02, ..., 10)
HOSTNUM=$(printf '%02d' "${SEQ}")

# 최종 호스트네임
HOSTNAME="rag-api-pub${HOSTNUM}"

# OS 내부 호스트네임 변경
hostnamectl set-hostname "${HOSTNAME}"
echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts

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
