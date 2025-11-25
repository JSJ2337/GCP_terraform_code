# =============================================================================
# 50-compute: Jenkins VM 및 관리용 VM
# =============================================================================

locals {
  jenkins_vm_name = "${var.management_project_id}-jenkins"
}

# -----------------------------------------------------------------------------
# 1) Jenkins VM 인스턴스
# -----------------------------------------------------------------------------
resource "google_compute_instance" "jenkins" {
  project      = var.management_project_id
  name         = local.jenkins_vm_name
  machine_type = var.jenkins_machine_type
  zone         = var.zone

  tags = ["jenkins", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = var.jenkins_image
      size  = var.jenkins_disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = var.vpc_self_link
    subnetwork = var.subnet_self_link

    # 외부 IP 할당 (필요시)
    dynamic "access_config" {
      for_each = var.assign_external_ip ? [1] : []
      content {
        # Ephemeral IP
      }
    }
  }

  # Service Account 연결
  service_account {
    email  = var.jenkins_service_account_email
    scopes = ["cloud-platform"]
  }

  # 메타데이터
  metadata = {
    enable-oslogin = "TRUE"
  }

  # Startup script (Jenkins 설치)
  metadata_startup_script = var.jenkins_startup_script != "" ? var.jenkins_startup_script : <<-EOF
    #!/bin/bash
    set -e

    # 시스템 업데이트
    apt-get update -y
    apt-get upgrade -y

    # Java 설치 (Jenkins 필수)
    apt-get install -y openjdk-17-jdk

    # Jenkins 설치
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    apt-get update -y
    apt-get install -y jenkins

    # Jenkins 시작
    systemctl enable jenkins
    systemctl start jenkins

    # Terraform 설치
    apt-get install -y gnupg software-properties-common
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt-get update -y
    apt-get install -y terraform

    # Terragrunt 설치
    TERRAGRUNT_VERSION="0.67.0"
    wget https://github.com/gruntwork-io/terragrunt/releases/download/v$${TERRAGRUNT_VERSION}/terragrunt_linux_amd64
    chmod +x terragrunt_linux_amd64
    mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

    # gcloud CLI 설치
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    apt-get update -y
    apt-get install -y google-cloud-cli

    # Git 설치
    apt-get install -y git

    echo "Jenkins setup completed!"
  EOF

  # 삭제 방지
  deletion_protection = var.deletion_protection

  labels = merge(var.labels, {
    purpose = "jenkins"
    role    = "ci-cd"
  })

  # 유지보수 정책
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  # 의존성: API가 활성화된 후 생성
  depends_on = []

  lifecycle {
    ignore_changes = [
      metadata_startup_script, # 스크립트 변경으로 재생성 방지
    ]
  }
}

# -----------------------------------------------------------------------------
# 2) Jenkins용 고정 외부 IP (선택사항)
# -----------------------------------------------------------------------------
resource "google_compute_address" "jenkins_ip" {
  count = var.create_static_ip ? 1 : 0

  project      = var.management_project_id
  name         = "${local.jenkins_vm_name}-ip"
  region       = var.region_primary
  address_type = "EXTERNAL"

  labels = var.labels
}

# -----------------------------------------------------------------------------
# 3) 추가 디스크 (Jenkins workspace용, 선택사항)
# -----------------------------------------------------------------------------
resource "google_compute_disk" "jenkins_data" {
  count = var.create_data_disk ? 1 : 0

  project = var.management_project_id
  name    = "${local.jenkins_vm_name}-data"
  type    = "pd-ssd"
  zone    = var.zone
  size    = var.data_disk_size

  labels = merge(var.labels, {
    purpose = "jenkins-data"
  })
}

resource "google_compute_attached_disk" "jenkins_data_attachment" {
  count = var.create_data_disk ? 1 : 0

  disk     = google_compute_disk.jenkins_data[0].id
  instance = google_compute_instance.jenkins.id
}
