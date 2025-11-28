#!/bin/bash
set -e

# Backend Service cleanup script
# Purpose: Remove Instance Groups from Backend Service before terraform apply
# This solves the "resourceInUseByAnotherResource" error

PROJECT_ID="gcp-gcby"
BACKEND_SERVICE_NAME="gcby-gs-backend"
TFVARS_FILE="terraform.tfvars"

echo "🧹 Backend Service Cleanup Script"
echo "=================================="
echo "Project: $PROJECT_ID"
echo "Backend Service: $BACKEND_SERVICE_NAME"
echo ""

# 1. terraform.tfvars에서 정의된 Instance Group 목록 추출
echo "📋 Step 1: Parsing terraform.tfvars for defined instance_groups..."
DEFINED_IGS=$(grep -A 100 'instance_groups = {' "$TFVARS_FILE" | \
  grep -E '^\s*"[^"]+"\s*=\s*{' | \
  sed 's/^\s*"\([^"]*\)"\s*=.*/\1/' || echo "")

if [ -z "$DEFINED_IGS" ]; then
  echo "⚠️  No instance groups defined in terraform.tfvars"
else
  echo "✅ Defined Instance Groups:"
  echo "$DEFINED_IGS" | while read ig; do
    echo "   - $ig"
  done
fi
echo ""

# 2. Backend Service에서 현재 연결된 Instance Group 목록 확인
echo "🔍 Step 2: Checking current backends in Backend Service..."
CURRENT_BACKENDS=$(gcloud compute backend-services describe "$BACKEND_SERVICE_NAME" \
  --global \
  --project="$PROJECT_ID" \
  --format='value(backends[].group)' 2>/dev/null || echo "")

if [ -z "$CURRENT_BACKENDS" ]; then
  echo "✅ No backends currently attached to Backend Service"
  echo "🎉 Nothing to clean up!"
  exit 0
fi

echo "✅ Current Backends:"
echo "$CURRENT_BACKENDS" | while read backend_url; do
  if [ -n "$backend_url" ]; then
    ig_name=$(echo "$backend_url" | awk -F'/' '{print $NF}')
    echo "   - $ig_name"
  fi
done
echo ""

# 3. 차이점 찾기: Backend에는 있지만 tfvars에는 없는 Instance Group
echo "🔍 Step 3: Finding Instance Groups to remove..."
TO_REMOVE=""
echo "$CURRENT_BACKENDS" | while IFS= read -r backend_url; do
  if [ -z "$backend_url" ]; then
    continue
  fi

  ig_name=$(echo "$backend_url" | awk -F'/' '{print $NF}')
  zone=$(echo "$backend_url" | awk -F'/' '{for(i=1;i<=NF;i++) if($i=="zones") print $(i+1)}')

  # tfvars에 정의되어 있는지 확인
  if echo "$DEFINED_IGS" | grep -q "^${ig_name}$"; then
    echo "   ✅ Keep: $ig_name (defined in terraform.tfvars)"
  else
    echo "   ❌ Remove: $ig_name (not in terraform.tfvars)"
    TO_REMOVE="${TO_REMOVE}${ig_name}:${zone}\n"
  fi
done
echo ""

# 4. Backend Service에서 제거
if [ -z "$TO_REMOVE" ]; then
  echo "🎉 No Instance Groups to remove!"
  exit 0
fi

echo "🗑️  Step 4: Removing Instance Groups from Backend Service..."
echo -e "$TO_REMOVE" | while IFS=':' read -r ig_name zone; do
  if [ -n "$ig_name" ] && [ -n "$zone" ]; then
    echo "   Removing: $ig_name (zone: $zone)"
    gcloud compute backend-services remove-backend "$BACKEND_SERVICE_NAME" \
      --instance-group="$ig_name" \
      --instance-group-zone="$zone" \
      --global \
      --project="$PROJECT_ID" \
      --quiet 2>&1 | sed 's/^/      /'

    if [ $? -eq 0 ]; then
      echo "   ✅ Successfully removed $ig_name"
    else
      echo "   ⚠️  Warning: Could not remove $ig_name"
    fi
    echo ""
  fi
done

echo "=================================="
echo "✅ Backend Service cleanup completed!"
echo "🚀 Now you can run: terragrunt apply"
