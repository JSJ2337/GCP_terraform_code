FROM jenkins/jenkins:2.479.1-lts-jdk17-jammy

USER root

# 최신 보안 패치 적용 및 필수 패키지 설치
RUN apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        apt-transport-https \
        unzip \
        wget \
        git \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Google Cloud SDK(gcloud) 설치
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-cloud-cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    gcloud version

# Terraform 설치
ARG TERRAFORM_VERSION=1.13.5
RUN curl -fsSLo terraform_${TERRAFORM_VERSION}_linux_amd64.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    curl -fsSLo terraform_SHA256SUMS https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS && \
    grep " terraform_${TERRAFORM_VERSION}_linux_amd64.zip" terraform_SHA256SUMS > terraform_SHA256SUMS_linux_amd64 && \
    sha256sum -c terraform_SHA256SUMS_linux_amd64 && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    install -m 0755 terraform /usr/local/bin/terraform && \
    rm -f terraform terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_SHA256SUMS terraform_SHA256SUMS_linux_amd64 && \
    terraform --version

# Terragrunt 설치
ARG TERRAGRUNT_VERSION=0.93.3
RUN curl -fsSLo terragrunt_linux_amd64 https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64 && \
    curl -fsSLo terragrunt_linux_amd64.sha256 https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64.sha256 && \
    sha256sum -c terragrunt_linux_amd64.sha256 && \
    install -m 0755 terragrunt_linux_amd64 /usr/local/bin/terragrunt && \
    rm -f terragrunt_linux_amd64 terragrunt_linux_amd64.sha256 && \
    terragrunt --version

# jenkins 사용자로 다시 전환
USER jenkins
