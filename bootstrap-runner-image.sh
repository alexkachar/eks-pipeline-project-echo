#!/usr/bin/env bash
# Builds and pushes the custom ARC runner image to ECR.
#
# Run this after a fresh `terraform apply` (Phase 1), before the first CI/CD
# job triggers. The runner scale set references this image; without it, runner
# pods will fail with ImagePullBackOff.
#
# Requires: docker, aws cli, jq

set -euo pipefail

REGION="eu-central-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/platform-actions-runner"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Authenticating to ECR..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo "==> Building runner image..."
docker build -t "$REPO:latest" "$SCRIPT_DIR/runners/"

echo "==> Pushing runner image..."
docker push "$REPO:latest"

echo "Done. Runner image pushed to $REPO:latest"
