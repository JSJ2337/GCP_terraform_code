# gce-mig 모듈

`google_compute_instance_template` + `google_compute_instance_group_manager` 조합으로 Managed Instance Group(MIG)을 생성합니다. 각 그룹은 고유 설정(존, 머신 타입, 서브넷, named port 등)을 가질 수 있으며, 출력되는 `instance_groups` 값을 Load Balancer 백엔드로 사용할 수 있습니다.

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 |
|------|------|------|--------|
| `project_id` | GCP 프로젝트 ID | `string` | - |
| `machine_type` | 기본 머신 타입 | `string` | `"e2-medium"` |
| `boot_disk_size_gb` | 기본 디스크 크기 | `number` | `30` |
| `boot_disk_type` | 기본 디스크 타입 | `string` | `"pd-balanced"` |
| `image_family` | 기본 이미지 패밀리 | `string` | `"debian-12"` |
| `image_project` | 기본 이미지 프로젝트 | `string` | `"debian-cloud"` |
| `startup_script` | 기본 startup script | `string` | `""` |
| `metadata`/`tags`/`labels` | 공통 메타데이터/태그/라벨 | map/list | `{}` / `[]` / `{}` |
| `service_account_email` | 기본 서비스 계정 | `string` | `""` |
| `service_account_scopes` | 서비스 계정 스코프 | `list(string)` | `["https://www.googleapis.com/auth/cloud-platform"]` |
| `groups` | MIG 정의 맵 (필수: `target_size`, `subnetwork_self_link`) | `map(object)` | `{}` |

각 그룹 항목은 다음 필드를 가집니다.

```hcl
mig_groups = {
  "web-mig" = {
    zone                 = "asia-northeast3-a"
    target_size          = 3
    subnetwork_self_link = "projects/<proj>/regions/.../subnetworks/..."
    machine_type         = "e2-medium"        # 선택
    enable_public_ip     = false              # 선택
    startup_script       = file("scripts/web.sh")
    named_ports = [
      { name = "http", port = 80 }
    ]
  }
}
```

## 출력

| 이름 | 설명 |
|------|------|
| `instance_group_manager_self_links` | MIG self-link 맵 |
| `instance_groups` | Load Balancer 백엔드에 사용할 instance group URL 맵 |

## 사용 예시

```hcl
module "gce_mig" {
  source     = "../../modules/gce-mig"
  project_id = var.project_id

  groups = {
    "web" = {
      zone                 = "asia-northeast3-a"
      target_size          = 3
      subnetwork_self_link = "projects/PROJECT/regions/asia-northeast3/subnetworks/dmz"
      named_ports = [
        { name = "http", port = 80 }
      ]
    }
  }
}

output "web_mig_group" {
  value = module.gce_mig.instance_groups["web"]
}
```
