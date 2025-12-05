# Load Balancer 모듈

이 모듈은 Google Cloud의 다양한 로드 밸런서(HTTP(S), Internal)를 생성하고 관리합니다.

## 기능

- **HTTP(S) Load Balancer**: 글로벌 로드 밸런싱, SSL/TLS 종료
- **Internal Load Balancer**: 내부 트래픽용 리전별 로드 밸런싱
- **Health Check**: HTTP, HTTPS, TCP 헬스 체크
- **Backend Service**: 백엔드 그룹 관리 및 로드 밸런싱
- **Cloud CDN**: 콘텐츠 캐싱 (HTTP(S) LB)
- **Identity-Aware Proxy**: 액세스 제어 (HTTP(S) LB)
- **SSL/TLS**: 인증서 관리 및 SSL 정책
- **URL Routing**: 호스트 및 경로 기반 라우팅

## 지원하는 로드 밸런서 타입

1. **http**: HTTP(S) Load Balancer (글로벌, 외부)
2. **internal**: Internal HTTP(S) Load Balancer (리전별, 내부)
3. **internal_classic**: Internal TCP/UDP Load Balancer (리전별, 내부)

## 사용법

### HTTP(S) Load Balancer (기본)

```hcl
module "http_lb" {
  source = "../../modules/load-balancer"

  project_id              = "my-project-id"
  lb_type                 = "http"
  backend_service_name    = "web-backend"
  forwarding_rule_name    = "web-lb-rule"

  backends = [
    {
      group = "projects/my-project/zones/us-central1-a/instanceGroups/web-ig"
    }
  ]

  # 헬스 체크
  health_check_name = "web-health-check"
  health_check_port = 80
  health_check_request_path = "/health"
}
```

### HTTPS Load Balancer with SSL

```hcl
module "https_lb" {
  source = "../../modules/load-balancer"

  project_id              = "my-project-id"
  lb_type                 = "http"
  use_ssl                 = true
  backend_service_name    = "web-backend-https"
  forwarding_rule_name    = "web-lb-https"
  target_https_proxy_name = "web-https-proxy"
  url_map_name            = "web-url-map"

  # SSL 인증서
  ssl_certificates = [
    "projects/my-project/global/sslCertificates/my-cert"
  ]

  backends = [
    {
      group           = "projects/my-project/zones/us-central1-a/instanceGroups/web-ig"
      balancing_mode  = "UTILIZATION"
      max_utilization = 0.8
    }
  ]

  # 헬스 체크
  health_check_name = "web-health-check"
  health_check_type = "https"
  health_check_port = 443
  health_check_request_path = "/health"
}
```

### HTTP(S) LB with Cloud CDN

```hcl
module "cdn_lb" {
  source = "../../modules/load-balancer"

  project_id              = "my-project-id"
  lb_type                 = "http"
  use_ssl                 = true
  backend_service_name    = "cdn-backend"
  forwarding_rule_name    = "cdn-lb"

  # Cloud CDN 활성화
  enable_cdn        = true
  cdn_cache_mode    = "CACHE_ALL_STATIC"
  cdn_default_ttl   = 3600
  cdn_max_ttl       = 86400
  cdn_client_ttl    = 3600

  backends = [
    {
      group = "projects/my-project/zones/us-central1-a/instanceGroups/web-ig"
    }
  ]

  ssl_certificates = [var.ssl_cert_id]
}
```

### Internal HTTP(S) Load Balancer

```hcl
module "internal_http_lb" {
  source = "../../modules/load-balancer"

  project_id              = "my-project-id"
  lb_type                 = "internal"
  region                  = "us-central1"
  network                 = "projects/my-project/global/networks/my-vpc"
  subnetwork              = "projects/my-project/regions/us-central1/subnetworks/my-subnet"
  backend_service_name    = "internal-backend"
  forwarding_rule_name    = "internal-lb"

  backends = [
    {
      group = "projects/my-project/zones/us-central1-a/instanceGroups/internal-ig"
    }
  ]

  health_check_name = "internal-health-check"
  health_check_port = 8080
}
```

### Internal TCP Load Balancer (Classic)

```hcl
module "internal_tcp_lb" {
  source = "../../modules/load-balancer"

  project_id              = "my-project-id"
  lb_type                 = "internal_classic"
  region                  = "us-central1"
  network                 = "projects/my-project/global/networks/my-vpc"
  subnetwork              = "projects/my-project/regions/us-central1/subnetworks/my-subnet"
  backend_service_name    = "tcp-backend"
  forwarding_rule_name    = "tcp-lb"

  forwarding_rule_ports = ["80", "443"]

  backends = [
    {
      group = "projects/my-project/zones/us-central1-a/instanceGroups/app-ig"
    }
  ]

  health_check_name = "tcp-health-check"
  health_check_type = "tcp"
  health_check_port = 80
}
```

### URL Routing (호스트 및 경로 기반)

```hcl
module "routing_lb" {
  source = "../../modules/load-balancer"

  project_id              = "my-project-id"
  lb_type                 = "http"
  use_ssl                 = true
  backend_service_name    = "default-backend"
  forwarding_rule_name    = "routing-lb"
  url_map_name            = "routing-url-map"

  backends = [
    {
      group = google_compute_instance_group.default.id
    }
  ]

  # 호스트 및 경로 라우팅
  host_rules = [
    {
      hosts        = ["api.example.com"]
      path_matcher = "api"
    },
    {
      hosts        = ["www.example.com"]
      path_matcher = "web"
    }
  ]

  path_matchers = [
    {
      name            = "api"
      default_service = google_compute_backend_service.api.id
      path_rules = [
        {
          paths   = ["/v1/*"]
          service = google_compute_backend_service.api_v1.id
        },
        {
          paths   = ["/v2/*"]
          service = google_compute_backend_service.api_v2.id
        }
      ]
    },
    {
      name            = "web"
      default_service = google_compute_backend_service.web.id
    }
  ]

  ssl_certificates = [var.ssl_cert_id]
}
```

### Identity-Aware Proxy (IAP)

```hcl
module "iap_lb" {
  source = "../../modules/load-balancer"

  project_id              = "my-project-id"
  lb_type                 = "http"
  use_ssl                 = true
  backend_service_name    = "iap-backend"
  forwarding_rule_name    = "iap-lb"

  # IAP 활성화
  enable_iap              = true
  iap_oauth2_client_id     = var.iap_client_id
  iap_oauth2_client_secret = var.iap_client_secret

  backends = [
    {
      group = google_compute_instance_group.internal_app.id
    }
  ]

  ssl_certificates = [var.ssl_cert_id]
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 기본값 | 필수 |
|------|------|------|--------|:----:|
| project_id | GCP 프로젝트 ID | `string` | - | yes |
| lb_type | 로드 밸런서 타입 | `string` | - | yes |
| region | 리전 (Internal LB용) | `string` | `"us-central1"` | no |
| backend_service_name | 백엔드 서비스 이름 | `string` | - | yes |
| forwarding_rule_name | 포워딩 규칙 이름 | `string` | - | yes |
| backends | 백엔드 그룹 목록 | `list(object)` | `[]` | no |
| health_check_name | 헬스 체크 이름 | `string` | `""` | no |
| health_check_port | 헬스 체크 포트 | `number` | `80` | no |
| use_ssl | SSL/HTTPS 사용 | `bool` | `false` | no |
| ssl_certificates | SSL 인증서 ID 목록 | `list(string)` | `[]` | no |
| enable_cdn | Cloud CDN 활성화 | `bool` | `false` | no |
| enable_iap | IAP 활성화 | `bool` | `false` | no |

## 출력 값

| 이름 | 설명 |
|------|------|
| backend_service_id | 백엔드 서비스 ID |
| health_check_id | 헬스 체크 ID |
| forwarding_rule_ip_address | 로드 밸런서 IP 주소 |
| static_ip_address | 고정 IP 주소 |

## 로드 밸런서 타입 비교

| 기능 | HTTP(S) LB | Internal HTTP(S) LB | Internal TCP LB |
|------|------------|---------------------|-----------------|
| **범위** | 글로벌 | 리전별 | 리전별 |
| **접근** | 외부 (인터넷) | 내부 (VPC) | 내부 (VPC) |
| **프로토콜** | HTTP, HTTPS, HTTP/2 | HTTP, HTTPS | TCP, UDP |
| **SSL 종료** | ✅ | ✅ | ❌ |
| **Cloud CDN** | ✅ | ❌ | ❌ |
| **IAP** | ✅ | ✅ | ❌ |
| **URL 라우팅** | ✅ | ✅ | ❌ |
| **용도** | 웹 애플리케이션 | 내부 API | 내부 서비스 |

## 모범 사례

1. **SSL/TLS 사용**
   - 프로덕션에서는 항상 HTTPS 사용
   - 최신 TLS 버전 및 강력한 암호화 suite 사용
   - Google-managed 인증서 사용 권장

2. **Health Check**
   - 의미 있는 헬스 체크 엔드포인트 구현
   - 적절한 타임아웃 및 임계값 설정
   - 헬스 체크 로깅 활성화

3. **Backend Configuration**
   - 적절한 세션 친화성 설정
   - 연결 드레이닝 활성화
   - 백엔드별 용량 조절

4. **Cloud CDN**
   - 정적 콘텐츠에 CDN 활성화
   - 적절한 캐시 TTL 설정
   - Cache-Control 헤더 활용

5. **모니터링**
   - 로깅 활성화 및 로그 분석
   - Cloud Monitoring으로 메트릭 추적
   - 알림 설정

6. **보안**
   - IAP로 내부 애플리케이션 보호
   - Cloud Armor로 DDoS 방어
   - SSL 정책 강화

## SSL 인증서 생성

### Google-managed 인증서
```bash
gcloud compute ssl-certificates create my-cert \
  --domains=example.com,www.example.com \
  --global
```

### Self-managed 인증서
```bash
gcloud compute ssl-certificates create my-cert \
  --certificate=./cert.pem \
  --private-key=./key.pem \
  --global
```

## 요구사항

- Terraform >= 1.6
- Google Provider >= 5.30

## 필요한 권한

- `roles/compute.loadBalancerAdmin` - 로드 밸런서 관리
- `roles/compute.networkAdmin` - 네트워크 구성

## 참고사항

- HTTP(S) LB는 글로벌 리소스 (리전 지정 불필요)
- Internal LB는 리전별 리소스 (리전 지정 필수)
- SSL 인증서는 사전 생성 필요
- Backend 인스턴스 그룹에 named port 설정 필요
- Cloud CDN은 HTTP(S) LB에서만 사용 가능
- IAP는 OAuth 클라이언트 사전 구성 필요
