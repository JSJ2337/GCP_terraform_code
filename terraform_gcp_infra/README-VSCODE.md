# VSCode에서 Terraform 프로젝트 사용하기

## WSL에서 VSCode 실행 (권장)

이 프로젝트는 `locals.tf` 파일을 심볼릭 링크로 사용합니다.
Windows VSCode가 WSL의 심볼릭 링크를 읽지 못하므로, WSL 내에서 VSCode를 실행해야 합니다.

### 1. Remote-WSL 확장 설치 (1회만)

Windows에서 VSCode를 열고:
1. Extensions (Ctrl+Shift+X)
2. "Remote - WSL" 검색
3. 설치

### 2. WSL에서 VSCode 실행

#### 방법 A: 스크립트 사용 (간편)

```bash
cd /mnt/d/jsj_wsl_data/terraform_gcp_infra
./open-vscode.sh
```

#### 방법 B: 직접 실행

```bash
cd /mnt/d/jsj_wsl_data/terraform_gcp_infra
code .
```

#### 방법 C: 특정 프로젝트만 열기

```bash
# jsj-game-c 프로젝트만 열기
cd /mnt/d/jsj_wsl_data/terraform_gcp_infra/environments/prod/jsj-game-c
code .

# proj-default-templet 템플릿 열기
cd /mnt/d/jsj_wsl_data/terraform_gcp_infra/environments/prod/proj-default-templet
code .
```

### 3. WSL VSCode인지 확인하는 방법

VSCode 좌측 하단에 **"WSL: Ubuntu"** (또는 다른 WSL 배포판 이름)가 표시되면 정상입니다.

### 4. Terraform 확장 설치 (WSL 내부에서)

WSL VSCode에서:
1. Extensions (Ctrl+Shift+X)
2. "HashiCorp Terraform" 검색
3. **"Install in WSL:Ubuntu"** 클릭 (중요!)

---

## 장점

✅ 심볼릭 링크 정상 작동
✅ Terraform 에러 없음
✅ 상위 `locals.tf` 하나만 수정하면 모든 레이어에 자동 반영
✅ Linux 환경과 완전히 동일한 경험

---

## 문제 해결

### "code: command not found" 에러가 발생하면

Windows VSCode의 PATH 설정이 WSL에 반영되지 않은 경우입니다.

**해결 방법:**

```bash
# Windows VSCode PATH를 WSL에서 직접 실행
/mnt/c/Users/YOUR_USERNAME/AppData/Local/Programs/Microsoft\ VS\ Code/bin/code .
```

또는 Windows VSCode를 열고:
- `Ctrl+Shift+P`
- "Remote-WSL: New Window" 실행
- 터미널에서 프로젝트 디렉토리로 이동

---

## 참고

현재 프로젝트 구조:
```
environments/prod/
├── proj-default-templet/    # 템플릿
│   ├── locals.tf            # 원본
│   └── */locals.tf          # → ../locals.tf (심볼릭 링크)
│
└── jsj-game-c/              # 실제 프로젝트
    ├── locals.tf            # 원본 (project: game-c)
    └── */locals.tf          # → ../locals.tf (심볼릭 링크)
```
