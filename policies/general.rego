# general.rego - General Terraform best practices
package terraform

# Warn: Deprecated Terraform versions
warn[msg] {
  terraform := input.terraform[_]
  version := terraform.required_version[0]
  not startswith(version, ">= 1.")
  msg := sprintf("Terraform version constraint '%s' is outdated — upgrade to 1.x or newer", [version])
}

# Warn: Resources with hard-coded availability zones (use data source instead)
warn[msg] {
  instance := input.resource.aws_instance[name]
  instance.availability_zone[0]
  msg := sprintf("EC2 instance '%s' has hard-coded availability_zone — consider using data source for flexibility", [name])
}

# Warn: Resources without explicit provider region (relies on default)
warn[msg] {
  bucket := input.resource.aws_s3_bucket[name]
  not input.provider.aws
  msg := sprintf("S3 bucket '%s' does not have explicit region — ensure default provider region is set", [name])
}

# Warn: Large default resource sizes that may incur unexpected costs
warn[msg] {
  instance := input.resource.aws_instance[name]
  instance_type := instance.instance_type[0]
  instance_type in ["c5.4xlarge", "c5.9xlarge", "r5.4xlarge", "r5.8xlarge", "x1e.4xlarge"]
  msg := sprintf("EC2 instance '%s' uses large instance type '%s' — verify this is intentional for cost control", [name, instance_type])
}

# Warn: No naming convention compliance
warn[msg] {
  resource := input.resource.aws_instance[name]
  not startswith(name, "prod-") and not startswith(name, "staging-") and not startswith(name, "dev-")
  msg := sprintf("Resource name '%s' does not follow naming convention (prod-*, staging-*, dev-*)", [name])
}

# Warn: Resources created without lifecycle management
warn[msg] {
  rds := input.resource.aws_rds_instance[name]
  not rds.skip_final_snapshot
  msg := sprintf("RDS instance '%s' should define skip_final_snapshot or specify final_snapshot_identifier for lifecycle safety", [name])
}

# Warn: No logging enabled on key resources
warn[msg] {
  alb := input.resource.aws_lb[name]
  alb.load_balancer_type[0] == "application"
  not alb.access_logs
  msg := sprintf("Application Load Balancer '%s' should have access_logs enabled for auditing", [name])
}

# Warn: EKS cluster without logging enabled
warn[msg] {
  cluster := input.resource.aws_eks_cluster[name]
  not cluster.enabled_cluster_log_types
  msg := sprintf("EKS cluster '%s' should enable cluster logging (enabled_cluster_log_types)", [name])
}

# Warn: No resource versioning for data integrity
warn[msg] {
  bucket := input.resource.aws_s3_bucket[name]
  not bucket.versioning
  msg := sprintf("S3 bucket '%s' should have versioning enabled for data protection", [name])
}

# Warn: Overly permissive resource-based policies
warn[msg] {
  lambda_permission := input.resource.aws_lambda_permission[name]
  lambda_permission.principal[0] == "*"
  msg := sprintf("Lambda permission '%s' allows any principal (principal: '*') — restrict to specific services/accounts", [name])
}
