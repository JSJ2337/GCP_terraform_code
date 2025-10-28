#Requires -RunAsAdministrator
# Windows Alloy 설치 스크립트
# 사용법: .\install-alloy.ps1

param(
    [string]$MimirUrl = "http://10.130.30.62:9009/api/v1/push",
    [string]$LokiUrl = "http://10.130.30.62:3100/loki/api/v1/push", 
    [string]$TempoEndpoint = "10.130.30.62:4317",
    [string]$TenantId = "idc-spd"
)

$ALLOY_VERSION = "1.10.0"
$INSTALL_DIR = "$env:ProgramFiles\GrafanaLabs\Alloy"
$DATA_DIR = "$env:ProgramData\GrafanaLabs\Alloy"
$CONFIG_FILE = "$INSTALL_DIR\config.alloy"

Write-Host "Alloy v$ALLOY_VERSION 설치 시작..." -ForegroundColor Green

# 1. 기존 Alloy 제거
Stop-Service -Name "Alloy" -Force -ErrorAction SilentlyContinue
if (Test-Path "$INSTALL_DIR\uninstall.exe") {
    & "$INSTALL_DIR\uninstall.exe" /S
    Start-Sleep -Seconds 3
}

# 2. Alloy 다운로드 및 설치
Write-Host "다운로드 중..." -ForegroundColor Yellow
$url = "https://github.com/grafana/alloy/releases/download/v$ALLOY_VERSION/alloy-installer-windows-amd64.exe.zip"
$zip = "$env:TEMP\alloy.zip"
$extract = "$env:TEMP\alloy-install"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $extract -Force

$installer = Get-ChildItem -Path $extract -Filter "*.exe" | Select-Object -First 1
Start-Process -FilePath $installer.FullName -ArgumentList "/S" -Wait

# 3. 디렉터리 생성
New-Item -Path $DATA_DIR -ItemType Directory -Force | Out-Null
New-Item -Path "$DATA_DIR\data" -ItemType Directory -Force | Out-Null

# 4. Config 파일 생성
$config = @"
// Windows Alloy Config - LGTM Stack
argument "mimir_url" {
  optional = true
  default  = "$MimirUrl"
}

argument "loki_url" {
  optional = true
  default  = "$LokiUrl"
}

argument "tempo_endpoint" {
  optional = true
  default  = "$TempoEndpoint"
}

argument "tenant_id" {
  optional = true
  default  = "$TenantId"
}

logging {
  level  = "info"
  format = "logfmt"
}

// Windows 메트릭
prometheus.exporter.windows "default" {
  enabled_collectors = ["cpu", "cs", "logical_disk", "net", "os", "service", "system", "memory"]
}

// 프로세스 메트릭
prometheus.exporter.process "default" {
  track_children = false
  matcher {
    name = "{{.Comm}}"  // Grafana 공식 문서 기준
    cmdline = [".+"]
  }
}

// 메트릭 스크레이핑
prometheus.scrape "windows" {
  targets         = prometheus.exporter.windows.default.targets
  scrape_interval = "30s"
  forward_to      = [prometheus.relabel.add_labels.receiver]
}

prometheus.scrape "process" {
  targets         = prometheus.exporter.process.default.targets
  scrape_interval = "30s"
  forward_to      = [prometheus.relabel.add_labels.receiver]
}

prometheus.relabel "add_labels" {
  forward_to = [prometheus.remote_write.mimir.receiver]
  
  rule {
    target_label = "hostname"
    replacement  = env("COMPUTERNAME")
  }
  
  rule {
    target_label = "job"
    replacement  = "windows"
  }
}

prometheus.remote_write "mimir" {
  endpoint {
    url = argument.mimir_url.value
    headers = {
      "X-Scope-OrgID" = argument.tenant_id.value,
    }
  }
}

// Windows 이벤트 로그
loki.source.windowsevent "application" {
  eventlog_name          = "Application"
  use_incoming_timestamp = true
  forward_to            = [loki.process.add_labels.receiver]
}

loki.source.windowsevent "system" {
  eventlog_name          = "System"
  use_incoming_timestamp = true
  forward_to            = [loki.process.add_labels.receiver]
}

loki.process "add_labels" {
  forward_to = [loki.write.default.receiver]
  
  stage.static_labels {
    values = {
      hostname = env("COMPUTERNAME")
      job      = "windows-logs"
    }
  }
}

loki.write "default" {
  endpoint {
    url       = argument.loki_url.value
    tenant_id = argument.tenant_id.value
  }
}

// OpenTelemetry 트레이스
otelcol.receiver.otlp "default" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }
  output { traces = [otelcol.processor.batch.default.input] }
}

otelcol.processor.batch "default" {
  timeout = "5s"
  output { traces = [otelcol.exporter.otlp.tempo.input] }
}

otelcol.exporter.otlp "tempo" {
  client {
    endpoint = argument.tempo_endpoint.value
    tls { insecure = true }
    headers = {
      "X-Scope-OrgID" = argument.tenant_id.value
    }
  }
}
"@

[System.IO.File]::WriteAllText($CONFIG_FILE, $config, [System.Text.UTF8Encoding]::new($false))

# 5. 서비스 설정
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Alloy"
if (Test-Path $regPath) {
    $args = "run `"$CONFIG_FILE`" --server.http.listen-addr=0.0.0.0:12345 --storage.path=`"$DATA_DIR\data`""
    $imagePath = "`"$INSTALL_DIR\alloy.exe`" $args"
    Set-ItemProperty -Path $regPath -Name "ImagePath" -Value $imagePath
    Set-ItemProperty -Path $regPath -Name "Start" -Value 2  # 자동 시작
}

# 6. 서비스 시작
Write-Host "서비스 시작 중..." -ForegroundColor Yellow
Start-Service -Name "Alloy"
Start-Sleep -Seconds 3

# 7. 정리
Remove-Item $zip, $extract -Recurse -Force -ErrorAction SilentlyContinue

# 8. 상태 확인
$service = Get-Service -Name "Alloy" -ErrorAction SilentlyContinue
if ($service.Status -eq "Running") {
    Write-Host "`n✅ Alloy 설치 완료!" -ForegroundColor Green
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "UI: http://localhost:12345" -ForegroundColor White
    Write-Host "Mimir: $MimirUrl" -ForegroundColor White
    Write-Host "Loki: $LokiUrl" -ForegroundColor White
    Write-Host "Tempo: $TempoEndpoint" -ForegroundColor White
    Write-Host "Tenant: $TenantId" -ForegroundColor White
    Write-Host "==============================" -ForegroundColor Cyan
} else {
    Write-Host "⚠️ 서비스가 실행되지 않음. 이벤트 로그 확인:" -ForegroundColor Red
    Get-EventLog -LogName Application -Source "Alloy" -Newest 5 | Format-List
}