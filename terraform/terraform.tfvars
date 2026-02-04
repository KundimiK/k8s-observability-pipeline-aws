This file contains your actual configuration values.
cat > terraform.tfvars << 'ENDOFFILE'
aws_region          = "us-east-1"
environment         = "dev"
cluster_name        = "observability-cluster"
cluster_version     = "1.29"
vpc_cidr            = "10.0.0.0/16"
node_instance_types = ["t3.large"]
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 5
log_retention_days  = 7
ENDOFFILE
