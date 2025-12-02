#!/bin/bash
# VM 목록 디버깅 스크립트

echo "=== gcloud 인증 확인 ==="
gcloud auth list

echo ""
echo "=== 현재 프로젝트 확인 ==="
gcloud config get-value project

echo ""
echo "=== gcp-gcby 프로젝트의 모든 VM (모든 상태) ==="
gcloud compute instances list --project=gcp-gcby

echo ""
echo "=== gcp-gcby 프로젝트의 RUNNING VM만 ==="
gcloud compute instances list --project=gcp-gcby --filter="status=RUNNING"

echo ""
echo "=== jsj-game-n 프로젝트의 모든 VM ==="
gcloud compute instances list --project=jsj-game-n

echo ""
echo "=== jsj-game-n 프로젝트의 RUNNING VM만 ==="
gcloud compute instances list --project=jsj-game-n --filter="status=RUNNING"

echo ""
echo "=== CSV 형식으로 출력 테스트 ==="
gcloud compute instances list \
    --project=gcp-gcby \
    --filter="status=RUNNING" \
    --format="csv[no-heading](name,zone,labels.role,labels.purpose,networkInterfaces[0].networkIP)"
