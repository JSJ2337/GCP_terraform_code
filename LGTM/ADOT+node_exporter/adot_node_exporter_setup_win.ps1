# 실행: PowerShell을 관리자 권한으로 실행하세요

Write-Host "==> CPU 아키텍처 감지"
switch ($env:PROCESSOR_ARCHITECTURE) {
  "AMD64" { $ARCH="amd64" }
  "ARM64" { $ARCH="arm64" }
  default { Write-Error "지원하지 않는 아키텍처: $($env:PROCESSOR_ARCHITECTURE)"; exit 1 }
}

Write-Host "==> ADOT Collector 최신 버전 조회"
$ADOT_RELEASE = Invoke-RestMethod -Uri "https://api.github.com/repos/aws-observability/aws-otel-collector/releases/latest"
$ADOT_VERSION = $ADOT_RELEASE.tag_name
Write-Host "    버전: $ADOT_VERSION"

$ADOT_URL = "https://aws-otel-collector.s3.amazonaws.com/windows/$ARCH/$ADOT_VERSION/aws-otel-collector.msi"
$ADOT_MSI = "$env:TEMP\aws-otel-collector.msi"
Write-Host "==> ADOT 다운로드: $ADOT_URL"
Invoke-WebRequest -Uri $ADOT_URL -OutFile $ADOT_MSI

Write-Host "==> ADOT 설치"
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$ADOT_MSI`" /qn"

Write-Host "==> node_exporter 최신 버전 조회"
$NE_RELEASE = Invoke-RestMethod -Uri "https://api.github.com/repos/prometheus/node_exporter/releases/latest"
$NE_VERSION = $NE_RELEASE.tag_name
Write-Host "    버전: $NE_VERSION"

$NE_ZIP = "$env:TEMP\node_exporter.zip"
$NE_URL = "https://github.com/prometheus/node_exporter/releases/download/$NE_VERSION/node_exporter-$NE_VERSION.windows-$ARCH.zip"
Write-Host "==> node_exporter 다운로드: $NE_URL"
Invoke-WebRequest -Uri $NE_URL -OutFile $NE_ZIP

Write-Host "==> node_exporter 설치"
Expand-Archive -Path $NE_ZIP -DestinationPath "C:\Program Files\node_exporter" -Force

Write-Host "==> Windows 서비스 등록"
sc.exe create node_exporter binPath= "\"C:\Program Files\node_exporter\node_exporter.exe\" --web.listen-address=:9100" start= auto
sc.exe start node_exporter

Write-Host "==> 설치 완료: ADOT Collector ($ADOT_VERSION), node_exporter ($NE_VERSION)"
