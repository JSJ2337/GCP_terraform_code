<#
.DESCRIPTION
# - CLEAN 64-bit Alloy v1.10.0 installation on Windows Server (IDC Environment)
# - Direct config generation without template files (v4 style)
# - 경로 문제 수정
#>
#Requires -RunAsAdministrator

# ========== PowerShell 실행 정책 설정 ==========
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# ========== 시스템 아키텍처 검증 ==========
$osArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
if ($osArch -notmatch "64.*bit") {
    Write-Error "[ERROR] 이 스크립트는 64-bit Windows에서만 실행 가능합니다."
    Exit 1
}

# ========== 변수 선언 (IDC 환경 설정) ==========
$HOSTNAME       = $env:COMPUTERNAME
$INSTANCE_ID    = (Get-WmiObject -Class Win32_ComputerSystemProduct).UUID
$INSTANCE_TYPE  = (Get-WmiObject -Class Win32_ComputerSystem).Model
$ACCOUNT_ID     = "idc-spd"
$JOB_NAME       = "prod"
$MIMIR_URL      = "http://10.130.30.62:9009/api/v1/push"
$TENANT_HEADER  = "ftt-lgtm"
$LOKI_URL       = "http://10.130.30.62:3100/loki/api/v1/push"
$TEMPO_HOST     = "10.130.30.62"
$LOKI_TENANT    = "ftt-lgtm"
$PYROSCOPE_URL  = "http://10.130.30.62:4040"
$ALLOY_PORT     = 12345

# ========== 올바른 설치 및 설정 경로 설정 ==========
$alloyProgFiles = "$env:ProgramFiles\GrafanaLabs\Alloy"  # 실행파일 위치
$alloyDataDir = "$env:ProgramData\GrafanaLabs\Alloy"     # 데이터 위치
$configPath = Join-Path $alloyProgFiles "config.alloy"  # 설정파일은 Program Files에

Write-Host "🏢 IDC Windows Server Alloy 설치 시작 (64-bit 설치)"
Write-Host "   Target: $HOSTNAME ($INSTANCE_TYPE)"

# ========== 기존 Alloy 완전 제거 ==========
Write-Host "🗑️ 기존 Alloy 완전 제거 중..."

# 서비스 중지
Try { Stop-Service -Name "Alloy" -Force -ErrorAction SilentlyContinue } Catch {}

# 언인스톨러 실행 (가능한 모든 경로에서)
@("$env:ProgramFiles\GrafanaLabs\Alloy", "${env:ProgramFiles(x86)}\GrafanaLabs\Alloy") | ForEach-Object {
    $uninstallPath = Join-Path $_ "uninstall.exe"
    if (Test-Path $uninstallPath) {
        Try {
            Start-Process -FilePath $uninstallPath -ArgumentList '/S' -Wait -ErrorAction SilentlyContinue
        } Catch {}
    }
}

# 디렉터리 강제 삭제
@("$env:ProgramFiles\GrafanaLabs\Alloy", "${env:ProgramFiles(x86)}\GrafanaLabs\Alloy") | ForEach-Object {
    if (Test-Path $_) {
        Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ========== 64-bit Alloy 다운로드 및 설치 ==========
$installerZipUrl = "https://github.com/grafana/alloy/releases/download/v1.10.0/alloy-installer-windows-amd64.exe.zip"
$installerZip = "$env:TEMP\alloy-installer-windows-amd64.exe.zip"
$extractDir = "$env:TEMP\alloy-install-x64"

Write-Host "📥 Alloy v1.10.0 x64 다운로드 중..."
Try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $installerZipUrl -OutFile $installerZip -UseBasicParsing -ErrorAction Stop
    Write-Host "✅ 다운로드 완료"
} Catch {
    Write-Error "[ERROR] 다운로드 실패: $_"; Exit 1
}

If (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive -Path $installerZip -DestinationPath $extractDir -Force

$installerExe = Join-Path $extractDir "alloy-installer-windows-amd64.exe"
Try {
    # 기본 경로로 설치 (레지스트리에서 config 경로는 별도 설정)
    Start-Process -FilePath $installerExe -ArgumentList "/S" -Wait -ErrorAction Stop
    Write-Host "✅ Alloy v1.10.0 x64 설치 완료"
} Catch {
    Write-Error "[ERROR] 설치 실패: $_"; Exit 1
}

# 설치 확인
Write-Host "🔍 설치 경로 확인 중..."
if (Test-Path $alloyProgFiles) {
    Write-Host "✅ 설치 경로 확인: $alloyProgFiles"
} else {
    Write-Error "[ERROR] Alloy 설치를 찾을 수 없습니다"; Exit 1
}

# ========== 필수 디렉터리 생성 ==========
$dataPath = "$env:ProgramData\GrafanaLabs\Alloy\data"
if (-not (Test-Path $alloyDataDir)) {
    New-Item -Path $alloyDataDir -ItemType Directory -Force
    Write-Host "✅ Alloy 설정 디렉터리 생성: $alloyDataDir"
}
if (-not (Test-Path $dataPath)) {
    New-Item -Path $dataPath -ItemType Directory -Force
    Write-Host "✅ 데이터 디렉터리 생성: $dataPath"
}

# textfile_inputs 디렉터리도 생성 (오류 방지)
$textfileInputsPath = Join-Path $alloyProgFiles "textfile_inputs"
if (-not (Test-Path $textfileInputsPath)) {
    New-Item -Path $textfileInputsPath -ItemType Directory -Force
    Write-Host "✅ textfile_inputs 디렉터리 생성: $textfileInputsPath"
}

# ========== Config 직접 생성 (v4 스타일, 수정된 버전) ==========
Write-Host "⚙️ 설정 파일 생성 중..."

$configContent = @"
logging {
  level  = "warn"
  format = "logfmt"
}

// Windows Event Log collection
loki.source.windowsevent "application" {
  eventlog_name = "Application"
  forward_to    = [loki.process.enrich.receiver]
}

loki.source.windowsevent "system" {
  eventlog_name = "System"
  forward_to    = [loki.process.enrich.receiver]
}

loki.source.windowsevent "security" {
  eventlog_name = "Security"
  forward_to    = [loki.process.enrich.receiver]
}

loki.process "enrich" {
  forward_to = [loki.write.default.receiver]
  
  stage.static_labels {
    values = {
      hostname      = "$HOSTNAME",
      instance_id   = "$INSTANCE_ID",
      instance_type = "$INSTANCE_TYPE",
      account_id    = "$ACCOUNT_ID",
      job           = "$JOB_NAME",
    }
  }
}

loki.write "default" {
  endpoint {
    url       = "$LOKI_URL"
    tenant_id = "$LOKI_TENANT"
  }
}

// Prometheus metrics (service collector 제외로 crash 방지)
prometheus.exporter.windows "win_metrics" {
  enabled_collectors = ["cpu", "cs", "logical_disk", "net", "os", "system", "time", "diskdrive", "service", "memory", "tcp", "udp", "process"]
}

prometheus.exporter.process "proc_metrics" {}

discovery.relabel "windows_targets" {
  targets = prometheus.exporter.windows.win_metrics.targets
  
  rule {
    target_label = "hostname"
    replacement  = "$HOSTNAME"
  }
  rule {
    target_label = "instance_id"
    replacement  = "$INSTANCE_ID"
  }
  rule {
    target_label = "instance_type"
    replacement  = "$INSTANCE_TYPE"
  }
  rule {
    target_label = "job"
    replacement  = "${ACCOUNT_ID}-node"
  }
}

discovery.relabel "process_targets" {
  targets = prometheus.exporter.process.proc_metrics.targets
  
  rule {
    target_label = "hostname"
    replacement  = "$HOSTNAME"
  }
  rule {
    target_label = "instance_id"
    replacement  = "$INSTANCE_ID"
  }
  rule {
    target_label = "instance_type"
    replacement  = "$INSTANCE_TYPE"
  }
  rule {
    target_label = "job"
    replacement  = "${ACCOUNT_ID}-proc"
  }
}

prometheus.scrape "windows" {
  targets         = discovery.relabel.windows_targets.output
  scrape_interval = "30s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}

prometheus.scrape "process" {
  targets         = discovery.relabel.process_targets.output
  scrape_interval = "30s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}

prometheus.remote_write "mimir" {
  endpoint {
    url = "$MIMIR_URL"
    headers = {
      "X-Scope-OrgID" = "$TENANT_HEADER",
    }
    queue_config {
      max_samples_per_send = 2000
      batch_send_deadline  = "5s"
      capacity             = 10000
    }
  }
}

// OpenTelemetry tracing
otelcol.receiver.otlp "idc_tempo_trace" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }
  output { traces = [otelcol.processor.batch.default.input] }
}

otelcol.processor.batch "default" {
  send_batch_size     = 1000
  send_batch_max_size = 2000
  timeout             = "2s"
  output { traces = [otelcol.exporter.otlp.tempo_out.input] }
}

otelcol.auth.headers "tempo_tenant" {
  header {
    key   = "X-Scope-OrgID"
    value = "${TENANT_HEADER}_tempo"
  }
}

otelcol.exporter.otlp "tempo_out" {
  client {
    endpoint = "${TEMPO_HOST}:4317"
    tls { insecure = true }
    auth = otelcol.auth.headers.tempo_tenant.handler
  }
}

// Pyroscope profiling (commented by default)
//pyroscope.write "central" {
//  endpoint {
//    url = "$PYROSCOPE_URL"
//    headers = {
//      "X-Scope-OrgID" = "${TENANT_HEADER}_profile",
//    }
//  }
//
//  external_labels = {
//    env     = "$TENANT_HEADER",
//    service = "$HOSTNAME",
//  }
//}
//
//discovery.relabel "local_pprof" {
//  targets = [
//    {
//      __address__ = "localhost:6060",
//      __scheme__  = "http",
//    },
//  ]
//}
//
//pyroscope.scrape "local_pprof" {
//  targets         = discovery.relabel.local_pprof.output
//  scrape_interval = "10s"
//  forward_to      = [pyroscope.write.central.receiver]
//}

"@

# Config 파일 저장 (UTF-8 BOM 없이)
Try {
    [System.IO.File]::WriteAllText($configPath, $configContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "✅ 설정 파일 생성 완료: $configPath"
} Catch {
    Write-Error "[ERROR] 설정 파일 생성 실패: $_"; Exit 1
}


# ========== Alloy 서비스 시작 ==========
Write-Host "🚀 Alloy 서비스 시작 중..."
Try {
    Start-Service -Name Alloy -ErrorAction Stop
} Catch {
    Write-Error "[ERROR] 서비스 시작 실패: $_"; Exit 1
}

# 서비스 상태 확인
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 2
    $svc = Get-Service -Name Alloy -ErrorAction SilentlyContinue
    if ($svc.Status -eq 'Running') {
        Write-Host "`n🎉 IDC Windows x64 Alloy 설치+기동 완료!"
        Write-Host "   System  : $HOSTNAME ($INSTANCE_TYPE)"
        Write-Host "   Version : Alloy v1.10.0"
        Write-Host "   Tenant  : $TENANT_HEADER"
        Write-Host "   Config  : $configPath"
        Write-Host ""
        Write-Host "🔗 Endpoints:"
        Write-Host "   UI      : http://${HOSTNAME}:$ALLOY_PORT/"
        Write-Host "   Ready   : http://${HOSTNAME}:$ALLOY_PORT/-/ready"
        Write-Host ""
        Write-Host "📊 Data Flow:"
        Write-Host "   Logs    : Windows EventLog → Loki ($LOKI_URL)"
        Write-Host "   Metrics : Windows + Process → Mimir ($MIMIR_URL)"
        Write-Host "   Traces  : OTLP → Tempo ($TEMPO_HOST:4317)"
        break
    }
    if ($i -eq 14) {
        Write-Error "[ERROR] 서비스 시작 타임아웃"; 
        Write-Host "이벤트 로그 확인:"
        Get-EventLog -LogName Application -Source "Alloy" -Newest 5 -ErrorAction SilentlyContinue
        Exit 1
    }
}

# 임시 파일 정리
Remove-Item $installerZip -ErrorAction SilentlyContinue
Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n✅ 깔끔한 IDC Windows x64 Alloy 구성 완료!"