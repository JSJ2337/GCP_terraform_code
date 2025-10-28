<#
.DESCRIPTION
# - Download & install Grafana Alloy v1.9.1 silently with /CONFIG
# - Write config with 변수값 치환 (템플릿 방식)
# - Start service
#>
#Requires -RunAsAdministrator

# --------- 변수 선언 (이 부분만 환경별로 수정하면 됨) ---------
$INSTANCE_ID    = $env:COMPUTERNAME
$INSTANCE_TYPE  = "windows"
$HOSTNAME       = $env:COMPUTERNAME
$ACCOUNT_ID     = "aws-rag"
$JOB_NAME       = "syslog"
$NODE_JOB_NAME  = "aws-rag_node"
$MIMIR_URL      = "http://10.23.50.147:9009/api/v1/push"
$TENANT_HEADER  = "aws-rag-ec2"
$LOKI_URL       = "http://10.23.50.147:3100/loki/api/v1/push"
$TEMPO_HOST     = "10.23.50.147"
$LOKI_TENANT    = "aws-rag-ec2"
$ALLOY_PORT     = 12345

$alloyProgFiles = "$env:ProgramFiles\GrafanaLabs\Alloy"
$configPath     = Join-Path $alloyProgFiles "config.alloy"
$configPathEsc  = $configPath -replace '\\','/'

# ---------- 기존 Alloy 언인스톨 ----------
If (Test-Path (Join-Path $alloyProgFiles "uninstall.exe")) {
    Try {
        Start-Process -FilePath (Join-Path $alloyProgFiles "uninstall.exe") `
            -ArgumentList '/S' -Wait -ErrorAction Stop
        Write-Host "[INFO] 기존 Alloy 제거 완료"
    } Catch {
        Write-Warning "[WARN] 언인스톨 중 문제 발생: $_"
    }
}

# ---------- Alloy 다운로드 및 설치 ----------
$installerZipUrl = "https://github.com/grafana/alloy/releases/download/v1.9.1/alloy-installer-windows-amd64.exe.zip"
$installerZip    = "$env:TEMP\alloy-installer-windows-amd64.exe.zip"
$extractDir      = "$env:TEMP\alloy-install"

Try {
    Invoke-WebRequest -Uri $installerZipUrl -OutFile $installerZip -UseBasicParsing -ErrorAction Stop
    Write-Host "[INFO] Installer 다운로드 완료"
} Catch {
    Write-Error "[ERROR] Installer 다운로드 실패: $_"; Exit 1
}

If (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive -Path $installerZip -DestinationPath $extractDir -Force

$installerExe = Join-Path $extractDir "alloy-installer-windows-amd64.exe"
Try {
    Start-Process -FilePath $installerExe `
        -ArgumentList "/S", "/CONFIG=`"$configPathEsc`"" `
        -Wait -ErrorAction Stop
    Write-Host "[INFO] Alloy v1.9.1 설치 완료"
} Catch {
    Write-Error "[ERROR] Alloy 설치 실패: $_"; Exit 1
}

# ---------- Config 템플릿: 변수 자동 치환 ----------
$configContent = @"
 // 로그 레벨 및 포맷 설정
logging {
  level  = "info"
  format = "logfmt"
}

// 윈도우용 프로메테우스 메트릭 Exporter
prometheus.exporter.windows "node" {}

// 윈도우 시스템 이벤트 로그를 Loki로 전송
loki.source.windowsevent "system" {
  eventlog_name          = "System"
  use_incoming_timestamp = true
  forward_to             = [loki.process.enrich.receiver]
}

// 윈도우 Application 이벤트 로그를 Loki로 전송
loki.source.windowsevent "application" {
  eventlog_name          = "Application"
  use_incoming_timestamp = true
  forward_to             = [loki.process.enrich.receiver]
}

// 윈도우 Security 이벤트 로그를 Loki로 전송
loki.source.windowsevent "security" {
  eventlog_name          = "Security"
  use_incoming_timestamp = true
  forward_to             = [loki.process.enrich.receiver]
}

// Loki 로그에 정적 라벨(메타데이터) 추가
loki.process "enrich" {
  stage.static_labels {
    values = {
      instance_id   = "$INSTANCE_ID",
      instance_type = "$INSTANCE_TYPE",
      hostname      = "$HOSTNAME",
      account_id    = "$ACCOUNT_ID",
      job           = "$JOB_NAME",
    }
  }
  forward_to = [loki.write.default.receiver]
}

// Loki로 로그 전송 (엔드포인트/테넌트 설정)
loki.write "default" {
  endpoint {
    url       = "$LOKI_URL"
    tenant_id = "$LOKI_TENANT"
  }
}

// 메트릭 라벨 추가 (윈도우 노드용)
discovery.relabel "node_lbl" {
  targets = prometheus.exporter.windows.node.targets

  rule {
    action       = "replace"
    target_label = "instance_id"
    replacement  = "$INSTANCE_ID"
  }
  rule {
    action       = "replace"
    target_label = "instance_type"
    replacement  = "$INSTANCE_TYPE"
  }
  rule {
    action       = "replace"
    target_label = "job"
    replacement  = "$NODE_JOB_NAME"
  }
}

// 윈도우 노드 메트릭 스크랩 및 Mimir로 전송
prometheus.scrape "node" {
  targets         = discovery.relabel.node_lbl.output
  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}

// 메트릭을 Mimir로 Remote Write
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

// tempo 연결 설정
otelcol.receiver.otlp "ftt_tempo_trace" {
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

"@

# ---------- Config 파일 기록 (UTF-8 BOM 없이) ----------
Try {
    [System.IO.File]::WriteAllText(
        $configPath,
        $configContent,
        (New-Object System.Text.UTF8Encoding $false)
    )
    Write-Host "[INFO] config.alloy 저장 완료"
} Catch {
    Write-Error "[ERROR] config 파일 저장 실패: $_"; Exit 1
}

# ---------- Alloy 서비스 기동 ----------
Try {
    Start-Service -Name Alloy -ErrorAction Stop
    Write-Host "[INFO] Alloy 서비스 시작"
} Catch {
    Write-Error "[ERROR] Alloy 서비스 시작 실패: $_"; Exit 1
}

for ($i=0; $i -lt 10; $i++) {
    Start-Sleep -Seconds 2
    $svc = Get-Service -Name Alloy -ErrorAction SilentlyContinue
    if ($svc.Status -eq 'Running') {
        Write-Host "`n✅ Alloy 설치+기동 완료"
        Write-Host " - Ready:   http://$(hostname):$ALLOY_PORT/-/ready"
        Write-Host " - Healthy: http://$(hostname):$ALLOY_PORT/-/healthy"
        Write-Host " - Metrics: http://$(hostname):$ALLOY_PORT/metrics"
        break
    }
    if ($i -eq 9) {
        Write-Error "[ERROR] Alloy 서비스가 Running 상태로 전환되지 않음"; Exit 1
    }
}
