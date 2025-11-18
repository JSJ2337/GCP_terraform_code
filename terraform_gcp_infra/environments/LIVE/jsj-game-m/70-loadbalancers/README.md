# 70-loadbalancers

## 자동 Instance Groups 매핑

이 레이어는 `50-workloads`에서 생성된 instance groups를 자동으로 읽어서 load balancer backend에 연결합니다.

### 일반 사용 (Apply/Plan)

```bash
cd 70-loadbalancers/lobby
terragrunt apply
```

자동으로 `50-workloads`의 outputs에서 "lobby"가 포함된 instance groups를 찾아서 매핑합니다.

### Run-all Destroy 시

`50-workloads`가 먼저 destroy되면 outputs를 읽을 수 없어 에러가 발생합니다. 
이 경우 환경변수를 설정하여 dependency를 건너뜁니다:

```bash
cd terraform_gcp_infra/environments/LIVE/jsj-game-m

# 환경변수 설정 후 destroy
export SKIP_WORKLOADS_DEPENDENCY=true
terragrunt run-all destroy --terragrunt-non-interactive

# 또는 한 줄로
SKIP_WORKLOADS_DEPENDENCY=true terragrunt run-all destroy --terragrunt-non-interactive
```

### 개별 Destroy

개별 모듈을 destroy할 때는 환경변수가 필요 없습니다:

```bash
cd 70-loadbalancers/lobby
terragrunt destroy
```

## 동작 원리

- **SKIP_WORKLOADS_DEPENDENCY=false** (기본값): dependency outputs 읽어서 자동 매핑
- **SKIP_WORKLOADS_DEPENDENCY=true**: dependency outputs 건너뛰기, auto_instance_groups = {}
