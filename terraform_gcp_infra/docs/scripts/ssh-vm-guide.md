# Automated SSH Connection via Bastion Host

## 🎯 Overview

**완전 자동화된 SSH 접속 스크립트** - 서버가 추가되어도 설정 파일 수정 불필요!

### 주요 특징

- ✅ **동적 VM 발견**: `gcloud compute instances list`로 실시간 VM 목록 자동 탐색
- ✅ **Zero Configuration**: VM 추가 시 스크립트나 설정 파일 수정 불필요
- ✅ **Label 기반 정보 표시**: role, purpose 등 VM 메타데이터 자동 표시
- ✅ **Bastion ProxyJump**: 자동으로 bastion을 통해 안전하게 연결
- ✅ **내부 DNS 지원**: hostname 우선, IP fallback
- ✅ **Multi-project 지원**: 여러 GCP 프로젝트 동시 스캔

## 📋 Prerequisites

### 1. gcloud CLI 설치 및 인증

```bash
# gcloud 설치 확인
gcloud version

# 인증 (아직 안했다면)
gcloud auth login

# 기본 프로젝트 설정 (선택사항)
gcloud config set project YOUR_PROJECT_ID
```

### 2. SSH 키 설정

```bash
# SSH 키 생성 (없는 경우)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Bastion Host에 공개키 복사
# (또는 startup script에서 자동으로 delabs-adm 계정이 생성됨)
```

### 3. 필요한 권한

GCP IAM 권한:
- `compute.instances.list`
- `compute.instances.get`

## 🚀 Usage

### 기본 사용법

```bash
# 기본 프로젝트에서 VM 목록 표시
./ssh_vm.sh
```

### 특정 프로젝트 지정

```bash
# 단일 프로젝트
./ssh_vm.sh gcp-gcby

# 여러 프로젝트
./ssh_vm.sh gcp-gcby jsj-game-n another-project
```

### 환경 변수로 커스터마이징

```bash
# Bastion host 변경
BASTION_HOST=custom-bastion.example.com ./ssh_vm.sh

# SSH 사용자명 변경
VM_USER=myuser BASTION_USER=bastionuser ./ssh_vm.sh

# 기본 프로젝트 목록 변경
DEFAULT_PROJECTS="proj1 proj2 proj3" ./ssh_vm.sh

# SSH 키 경로 변경
SSH_KEY=~/.ssh/custom_key ./ssh_vm.sh
```

## 🎬 Demo

```bash
$ ./ssh_vm.sh

╔═══════════════════════════════════════════════════════════════╗
║       Automated SSH Connection via Bastion Host              ║
║       Dynamic VM Discovery - No Config Required              ║
╚═══════════════════════════════════════════════════════════════╝

[INFO] Scanning projects: gcp-gcby jsj-game-n
[INFO] Discovering VMs across projects...
[INFO] Scanning project: gcp-gcby
[INFO] Scanning project: jsj-game-n
[SUCCESS] Found 5 VM(s)

═══════════════════════════════════════════════════════════════
           Available VMs (Auto-discovered)
═══════════════════════════════════════════════════════════════

1) delabs-terraform-jenkins [Project: gcp-gcby] [Role: ci-cd] [Purpose: jenkins]
2) delabs-test [Project: gcp-gcby] [Role: test] [Purpose: testing]
3) game-server-1 [Project: jsj-game-n] [Role: game] [Purpose: production]
4) game-server-2 [Project: jsj-game-n] [Role: game] [Purpose: production]
5) db-server [Project: jsj-game-n] [Role: database] [Purpose: postgresql]
6) Quit

Select VM to connect (or 'q' to quit): 3

[SUCCESS] Selected: game-server-1
[INFO] Connecting to game-server-1 via bastion host...
[INFO] Target: game-server-1.delabsgames.gg
[INFO] Bastion: delabs-bastion.delabsgames.gg

[delabs-adm@game-server-1 ~]$
```

## ⚙️ Configuration

### 스크립트 상단 설정 변수

```bash
# Bastion host 설정
BASTION_HOST="${BASTION_HOST:-delabs-bastion.delabsgames.gg}"
BASTION_USER="${BASTION_USER:-delabs-adm}"

# VM SSH 사용자
VM_USER="${VM_USER:-delabs-adm}"

# 기본 프로젝트 목록 (공백으로 구분)
DEFAULT_PROJECTS="${DEFAULT_PROJECTS:-gcp-gcby jsj-game-n}"

# SSH 키 경로
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
```

### 영구 설정 (선택사항)

`~/.bashrc` 또는 `~/.zshrc`에 추가:

```bash
# GCP SSH VM Script 설정
export BASTION_HOST="delabs-bastion.delabsgames.gg"
export BASTION_USER="delabs-adm"
export VM_USER="delabs-adm"
export DEFAULT_PROJECTS="gcp-gcby jsj-game-n"

# Alias 추가
alias sssh='/path/to/terraform_gcp_infra/scripts/ssh_vm.sh'
```

그러면 어디서든 `sssh` 명령으로 실행 가능!

## 🔒 Security Best Practices

### 1. SSH 키 관리

```bash
# SSH Agent 사용 (비밀번호 매번 입력 불필요)
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa
```

### 2. Bastion Host 접근 제한

```bash
# Bastion의 방화벽 규칙으로 특정 IP만 허용
# (이미 terraform에서 설정되어 있음)
```

### 3. SSH Config 백업 (선택사항)

`~/.ssh/config`에 수동 설정 추가:

```ssh-config
# Bastion Host
Host bastion
    HostName delabs-bastion.delabsgames.gg
    User delabs-adm
    IdentityFile ~/.ssh/id_rsa

# 모든 내부 VM (와일드카드)
Host *.delabsgames.gg !bastion
    ProxyJump bastion
    User delabs-adm
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
```

이렇게 하면 스크립트 없이도 `ssh vm-name.delabsgames.gg` 가능!

## 📝 How It Works

### 동작 원리

1. **VM 발견 단계**
   ```bash
   gcloud compute instances list \
     --project="$project" \
     --filter="status=RUNNING" \
     --format="csv(name,zone,labels,networkIP)"
   ```

2. **Bastion 제외**
   - VM 이름에 "bastion" 포함 시 자동 제외

3. **메뉴 생성**
   - bash `select` 명령으로 인터랙티브 메뉴 생성
   - labels 정보 자동 표시

4. **SSH 연결**
   ```bash
   ssh -o ProxyJump=bastion-user@bastion-host \
       vm-user@target-vm.internal
   ```

### 왜 설정 파일 수정이 필요 없나?

- ❌ **기존 방식**: VM 추가 → SSH config 수정 → VM 목록 관리
- ✅ **이 스크립트**: VM 추가 → 끝! (스크립트가 자동으로 발견)

스크립트 실행 시마다 `gcloud` API로 **실시간 VM 목록**을 가져오므로, Terraform으로 VM을 추가하면 **즉시 메뉴에 표시**됩니다!

## 🐛 Troubleshooting

### gcloud 인증 에러

```bash
# 재인증
gcloud auth login

# 현재 인증 확인
gcloud auth list
```

### VM이 표시되지 않음

```bash
# 프로젝트 확인
gcloud projects list

# VM 목록 수동 확인
gcloud compute instances list --project=YOUR_PROJECT

# 권한 확인
gcloud projects get-iam-policy YOUR_PROJECT
```

### SSH 연결 실패

```bash
# Bastion 연결 테스트
ssh delabs-adm@delabs-bastion.delabsgames.gg

# 방화벽 규칙 확인
gcloud compute firewall-rules list --project=YOUR_PROJECT

# SSH 키 확인
ssh-add -l
```

### ProxyJump 에러

```bash
# SSH 버전 확인 (7.3 이상 필요)
ssh -V

# 수동 연결 테스트
ssh -J bastion-user@bastion-host vm-user@target-vm
```

## 🎨 Advanced Usage

### SCP 파일 전송

```bash
# ProxyJump를 사용한 SCP
scp -o ProxyJump=delabs-adm@delabs-bastion.delabsgames.gg \
    local-file.txt \
    delabs-adm@target-vm.delabsgames.gg:/remote/path/
```

### Port Forwarding

```bash
# Local port forwarding
ssh -L 8080:localhost:80 \
    -o ProxyJump=delabs-adm@delabs-bastion.delabsgames.gg \
    delabs-adm@target-vm.delabsgames.gg
```

### 명령 실행 (interactive 없이)

```bash
ssh -o ProxyJump=delabs-adm@delabs-bastion.delabsgames.gg \
    delabs-adm@target-vm.delabsgames.gg \
    "uptime && df -h"
```

## 📚 References

- [GCP Bastion Host Best Practices](https://cloud.google.com/compute/docs/connect/ssh-using-bastion-host)
- [SSH ProxyJump Documentation](https://www.redhat.com/en/blog/ssh-proxy-bastion-proxyjump)
- [gcloud CLI Scripting Guide](https://cloud.google.com/sdk/docs/scripting-gcloud)

## 📧 Support

문제가 있거나 개선 사항이 있다면:
1. 스크립트 로그 확인
2. Troubleshooting 섹션 참고
3. 팀 슬랙 채널에 문의

---

**Made with ❤️ for Delabs DevOps Team**
