#!/usr/bin/env bash
# Teardown script — run this instead of bare `terraform destroy`.
#
# The ALB is created by the ALB Controller from the Kubernetes Ingress, so it
# is NOT in Terraform state. Destroying the cluster while the ALB still exists
# causes the VPC delete to fail. This script removes the app Helm release first
# so the ALB Controller can clean up the ALB before Terraform runs.

set -euo pipefail

TERRAFORM_DIR="$(cd "$(dirname "$0")/terraform/environments/dev" && pwd)"

echo "==> Checking cluster is reachable..."
if ! kubectl cluster-info --request-timeout=5s &>/dev/null; then
  echo "ERROR: kubectl cannot reach the cluster. Update your kubeconfig and retry."
  echo "  aws eks update-kubeconfig --name todo-app-dev --region eu-central-1"
  exit 1
fi

echo "==> Uninstalling todo-app Helm release (lets ALB Controller delete the ALB)..."
if helm status todo-app -n todo-app &>/dev/null; then
  helm uninstall todo-app -n todo-app
else
  echo "    todo-app release not found — skipping."
fi

echo "==> Waiting for ALB to be deleted (up to 3 minutes)..."
for i in $(seq 1 36); do
  ALB_COUNT=$(aws elbv2 describe-load-balancers --region eu-central-1 \
    --query 'length(LoadBalancers[?contains(LoadBalancerName, `k8s-todoapp`)])' \
    --output text 2>/dev/null || echo "0")
  if [ "$ALB_COUNT" = "0" ]; then
    echo "    ALB deleted."
    break
  fi
  if [ "$i" = "36" ]; then
    echo "ERROR: ALB was not deleted after 3 minutes. Check ALB Controller logs:"
    echo "  kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
    exit 1
  fi
  echo "    Still waiting ($i/36)..."
  sleep 5
done

echo "==> Clearing alb_dns_name in tfvars (prevents stale Route 53 record on next apply)..."
sed -i 's/^alb_dns_name = ".*"/alb_dns_name = ""/' "$TERRAFORM_DIR/terraform.tfvars"

echo "==> Running terraform destroy..."
cd "$TERRAFORM_DIR"
terraform destroy "$@"

echo ""
echo "Done. To recreate the stack, see the Bootstrap sequence section in README.md."
