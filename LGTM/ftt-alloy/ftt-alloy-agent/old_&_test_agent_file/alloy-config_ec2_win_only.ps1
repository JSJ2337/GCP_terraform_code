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
$configPathEsc  = $configPath -replace '\','/'
$configTemplatePath = ".\config.win.alloy"

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
(Get-Content $configTemplatePath -Raw) `
    -replace '__INSTANCE_ID__', $INSTANCE_ID `
    -replace '__INSTANCE_TYPE__', $INSTANCE_TYPE `
    -replace '__HOSTNAME__', $HOSTNAME `
    -replace '__ACCOUNT_ID__', $ACCOUNT_ID `
    -replace '__JOB_NAME__', $JOB_NAME `
    -replace '__LOKI_URL__', $LOKI_URL `
    -replace '__LOKI_TENANT__', $LOKI_TENANT `
    -replace '__NODE_JOB_NAME__', $NODE_JOB_NAME `
    -replace '__MIMIR_URL__', $MIMIR_URL `
    -replace '__TENANT_HEADER__', $TENANT_HEADER `
    -replace '__TEMPO_HOST__', $TEMPO_HOST | Out-File -FilePath $configPath -Encoding utf8NoBOM

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