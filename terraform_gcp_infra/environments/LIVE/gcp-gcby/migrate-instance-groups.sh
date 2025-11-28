#!/bin/bash
# Instance Group 마이그레이션 스크립트
# 50-workloads -> 70-loadbalancers/gs

set -e

WORKLOADS_DIR="/var/jenkins_home/jobs/(LIVE) gcp-gcby/workspace/terraform_gcp_infra/environments/LIVE/gcp-gcby/50-workloads"
LB_DIR="/var/jenkins_home/jobs/(LIVE) gcp-gcby/workspace/terraform_gcp_infra/environments/LIVE/gcp-gcby/70-loadbalancers/gs"

echo "=== Instance Group 마이그레이션 시작 ==="

# Step 1: 50-workloads에서 Instance Group state 제거
echo ""
echo "Step 1: 50-workloads에서 Instance Group state 제거..."
cd "$WORKLOADS_DIR"
terraform state rm 'google_compute_instance_group.custom["gcby-gs-ig-a"]' || echo "  ⚠ 이미 제거되었거나 존재하지 않음"
terraform state rm 'google_compute_instance_group.custom["gcby-gs-ig-b"]' || echo "  ⚠ 이미 제거되었거나 존재하지 않음"
echo "  ✓ State 제거 완료"

# Step 2: 50-workloads apply
echo ""
echo "Step 2: 50-workloads apply (VM outputs만 업데이트)..."
cd "$WORKLOADS_DIR"
terraform apply -auto-approve
echo "  ✓ 50-workloads apply 완료"

# Step 3: 70-loadbalancers/gs에 Instance Group import
echo ""
echo "Step 3: 70-loadbalancers/gs에 기존 Instance Group import..."
cd "$LB_DIR"

# Zone 정보 확인
echo "  - gcby-gs-ig-a를 us-west1-a에서 import..."
terraform import 'google_compute_instance_group.lb_instance_group["gcby-gs-ig-a"]' \
  "projects/gcp-gcby/zones/us-west1-a/instanceGroups/gcby-gs-ig-a" || echo "  ⚠ import 실패 또는 이미 존재"

echo "  - gcby-gs-ig-b를 us-west1-b에서 import..."
terraform import 'google_compute_instance_group.lb_instance_group["gcby-gs-ig-b"]' \
  "projects/gcp-gcby/zones/us-west1-b/instanceGroups/gcby-gs-ig-b" || echo "  ⚠ import 실패 또는 이미 존재"

echo "  ✓ Import 완료"

# Step 4: 70-loadbalancers/gs apply
echo ""
echo "Step 4: 70-loadbalancers/gs apply..."
cd "$LB_DIR"
terraform apply -auto-approve
echo "  ✓ 70-loadbalancers/gs apply 완료"

echo ""
echo "=== ✓ 마이그레이션 완료 ==="
echo ""
echo "결과 확인:"
echo "  - 50-workloads: VM만 관리 (Instance Group 제거됨)"
echo "  - 70-loadbalancers/gs: Instance Group + Backend Service 관리"
