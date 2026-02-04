#!/bin/bash
# AWS Kubernetes Observability Pipeline - Verification Script
# This script verifies the deployment is working correctly

set -e

echo "=========================================="
echo "AWS Kubernetes Observability Pipeline"
echo "Verification Script"
echo "=========================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo ""
echo "1. Checking EKS Cluster..."
if aws eks describe-cluster --name observability-cluster --query 'cluster.status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    check_pass "EKS cluster is ACTIVE"
else
    check_fail "EKS cluster not found or not active"
fi

echo ""
echo "2. Checking Kubernetes Nodes..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODE_COUNT" -ge 3 ]; then
    check_pass "Found $NODE_COUNT nodes (expected 3+)"
else
    check_fail "Found $NODE_COUNT nodes (expected 3+)"
fi

READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep " Ready" | wc -l)
if [ "$READY_NODES" -eq "$NODE_COUNT" ]; then
    check_pass "All $READY_NODES nodes are Ready"
else
    check_fail "Only $READY_NODES of $NODE_COUNT nodes are Ready"
fi

echo ""
echo "3. Checking Observability Namespace..."
if kubectl get namespace observability &>/dev/null; then
    check_pass "Observability namespace exists"
else
    check_fail "Observability namespace not found"
fi

echo ""
echo "4. Checking Vector Pods..."
POD_COUNT=$(kubectl get pods -n observability -l app=vector --no-headers 2>/dev/null | wc -l)
if [ "$POD_COUNT" -ge 3 ]; then
    check_pass "Found $POD_COUNT Vector pods"
else
    check_fail "Found $POD_COUNT Vector pods (expected 3+)"
fi

RUNNING_PODS=$(kubectl get pods -n observability -l app=vector --no-headers 2>/dev/null | grep "Running" | wc -l)
if [ "$RUNNING_PODS" -eq "$POD_COUNT" ]; then
    check_pass "All $RUNNING_PODS Vector pods are Running"
else
    check_fail "Only $RUNNING_PODS of $POD_COUNT pods are Running"
fi

echo ""
echo "5. Checking IRSA Configuration..."
VECTOR_POD=$(kubectl get pods -n observability -l app=vector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$VECTOR_POD" ]; then
    ROLE_ARN=$(kubectl exec -n observability $VECTOR_POD -- aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "")
    if echo "$ROLE_ARN" | grep -q "observability-cluster-vector-role"; then
        check_pass "IRSA configured correctly"
    else
        check_fail "IRSA not configured correctly"
    fi
else
    check_fail "Could not verify IRSA (no running pod)"
fi

echo ""
echo "6. Checking CloudWatch Log Groups..."
if aws logs describe-log-groups --log-group-name-prefix /vector/logs/application --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "/vector/logs/application"; then
    check_pass "Log group /vector/logs/application exists"
else
    check_fail "Log group /vector/logs/application not found"
fi

echo ""
echo "7. Checking for Recent Log Events..."
LAST_EVENT=$(aws logs describe-log-streams --log-group-name /vector/logs/application --order-by LastEventTime --descending --limit 1 --query 'logStreams[0].lastEventTimestamp' --output text 2>/dev/null || echo "None")
if [ "$LAST_EVENT" != "None" ] && [ "$LAST_EVENT" != "null" ]; then
    check_pass "Recent log events found"
else
    check_warn "No recent log events (might need a few minutes)"
fi

echo ""
echo "8. Checking CloudWatch Dashboards..."
if aws cloudwatch get-dashboard --dashboard-name observability-cluster-logs-dashboard &>/dev/null; then
    check_pass "Logs dashboard exists"
else
    check_fail "Logs dashboard not found"
fi

if aws cloudwatch get-dashboard --dashboard-name observability-cluster-metrics-dashboard &>/dev/null; then
    check_pass "Metrics dashboard exists"
else
    check_fail "Metrics dashboard not found"
fi

echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All checks passed! Deployment is healthy.${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some checks failed. Please review the output above.${NC}"
    exit 1
fi
