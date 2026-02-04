#!/bin/bash
# AWS Kubernetes Observability Pipeline - Cleanup Script
# This script removes all deployed resources

set -e

echo "=========================================="
echo "AWS Kubernetes Observability Pipeline"
echo "Cleanup Script"
echo "=========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo ""
print_warning "This will DELETE all resources created by this project."
print_warning "This action cannot be undone."
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Delete Kubernetes resources
echo ""
echo "Deleting Kubernetes resources..."
if kubectl get namespace observability &> /dev/null; then
    kubectl delete -f kubernetes/vector/ --ignore-not-found=true
    print_status "Kubernetes resources deleted"
else
    print_warning "Observability namespace not found, skipping..."
fi

# Delete CloudWatch log groups
echo ""
echo "Deleting CloudWatch log groups..."
aws logs delete-log-group --log-group-name /vector/logs/application 2>/dev/null || true
aws logs delete-log-group --log-group-name /vector/logs/metrics 2>/dev/null || true
print_status "CloudWatch log groups deleted"

# Destroy Terraform infrastructure
echo ""
echo "Destroying Terraform infrastructure..."
cd terraform
terraform destroy -auto-approve
print_status "Terraform infrastructure destroyed"

echo ""
print_status "Cleanup completed successfully!"
echo ""
echo "Verify cleanup by checking:"
echo "  - AWS EKS: No 'observability-cluster' cluster"
echo "  - AWS VPC: No 'observability-cluster-vpc' VPC"
echo "  - AWS CloudWatch: No /vector/* log groups"
