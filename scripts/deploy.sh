#!/bin/bash
# AWS Kubernetes Observability Pipeline - Deployment Script
# This script deploys the complete infrastructure and Vector

set -e

echo "=========================================="
echo "AWS Kubernetes Observability Pipeline"
echo "Deployment Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check prerequisites
echo ""
echo "Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install it first."
    exit 1
fi
print_status "AWS CLI found"

if ! command -v terraform &> /dev/null; then
    print_error "Terraform not found. Please install it first."
    exit 1
fi
print_status "Terraform found"

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install it first."
    exit 1
fi
print_status "kubectl found"

# Verify AWS credentials
echo ""
echo "Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Run 'aws configure' first."
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "AWS Account: $ACCOUNT_ID"

# Deploy Terraform infrastructure
echo ""
echo "=========================================="
echo "Deploying Terraform Infrastructure"
echo "=========================================="

cd terraform

print_status "Initializing Terraform..."
terraform init

print_status "Planning deployment..."
terraform plan -out=tfplan

echo ""
read -p "Do you want to apply this plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_warning "Deployment cancelled."
    exit 0
fi

print_status "Applying Terraform configuration..."
terraform apply tfplan

# Get outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)

print_status "Infrastructure deployed successfully!"

# Configure kubectl
echo ""
echo "=========================================="
echo "Configuring kubectl"
echo "=========================================="

print_status "Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

print_status "Verifying cluster connection..."
kubectl get nodes

# Update serviceaccount with correct account ID
echo ""
echo "=========================================="
echo "Deploying Vector"
echo "=========================================="

cd ../kubernetes/vector

print_status "Updating ServiceAccount with AWS Account ID..."
sed -i "s/YOUR_ACCOUNT_ID/$ACCOUNT_ID/g" serviceaccount.yaml

print_status "Applying Kubernetes manifests..."
kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f configmap.yaml
kubectl apply -f daemonset.yaml

# Wait for pods to be ready
print_status "Waiting for Vector pods to be ready..."
kubectl wait --for=condition=ready pod -l app=vector -n observability --timeout=300s

# Verify deployment
echo ""
echo "=========================================="
echo "Verifying Deployment"
echo "=========================================="

print_status "Vector pods status:"
kubectl get pods -n observability

echo ""
print_status "Deployment completed successfully!"
echo ""
echo "Dashboard URLs:"
cd ../../terraform
terraform output logs_dashboard_url
terraform output metrics_dashboard_url
