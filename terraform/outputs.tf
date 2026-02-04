This file defines what information Terraform shows after deployment.
cat > outputs.tf << 'ENDOFFILE'
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Run this command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vector_role_arn" {
  description = "IAM role ARN for Vector ServiceAccount"
  value       = module.vector_irsa.iam_role_arn
}

output "logs_dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.cluster_name}-logs-dashboard"
}

output "metrics_dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.cluster_name}-metrics-dashboard"
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.aws_region
}
ENDOFFILE
