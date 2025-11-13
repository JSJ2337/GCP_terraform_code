# 70-loadbalancers 그룹

이 디렉터리는 여러 종류의 Load Balancer 레이어를 모아둔 그룹입니다. Terragrunt 실행 시에는 아래 하위 디렉터리(각 레이어)를 지정해 사용하세요.

| 서브 디렉터리 | 설명 | 자동 연결되는 인스턴스 그룹 |
|---------------|------|--------------------------------|
| `lobby/` | 외부 로비 트래픽용 HTTP(S) Load Balancer | `jsj-lobby-*` IG만 필터링하여 auto_instance_groups로 주입 |
| `web/`   | 웹 서비스용 HTTP(S) Load Balancer | `jsj-web-*` IG만 자동 주입 |

새로운 로드밸런서가 필요하다면 이 폴더 아래에 디렉터리를 추가하고, 해당 `terragrunt.hcl`에서 `dependency "workloads"` 출력값을 원하는 규칙으로 필터링해 `auto_instance_groups`에 전달하면 됩니다.
