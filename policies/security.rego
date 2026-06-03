# security.rego - Enforce security best practices
package terraform

# Deny: S3 buckets with public ACL
deny[msg] {
  bucket := input.resource.aws_s3_bucket[name]
  acl := bucket.acl[0]
  acl in ["public-read", "public-read-write"]
  msg := sprintf("S3 bucket '%s' has public ACL '%s' — must be private", [name, acl])
}

# Deny: RDS instances without encryption
deny[msg] {
  rds := input.resource.aws_rds_instance[name]
  not rds.storage_encrypted
  msg := sprintf("RDS instance '%s' must have encryption enabled (storage_encrypted = true)", [name])
}

# Deny: RDS with publicly accessible setting enabled
deny[msg] {
  rds := input.resource.aws_rds_instance[name]
  rds.publicly_accessible[0] == true
  msg := sprintf("RDS instance '%s' must not be publicly accessible", [name])
}

# Deny: EC2 instances without VPC (must use VPC, not EC2-Classic)
warn[msg] {
  instance := input.resource.aws_instance[name]
  not instance.subnet_id
  msg := sprintf("EC2 instance '%s' should be placed in a VPC (specify subnet_id)", [name])
}

# Deny: Security groups allowing unrestricted access (0.0.0.0/0) on sensitive ports
deny[msg] {
  sg := input.resource.aws_security_group[name]
  rule := sg.ingress[_]
  rule.cidr_blocks[_] == "0.0.0.0/0"
  port := rule.from_port[0]
  port in [22, 3306, 5432, 6379, 27017]
  msg := sprintf("Security group '%s' allows unrestricted (0.0.0.0/0) access to sensitive port %d — restrict to known IPs", [name, port])
}

# Deny: EKS cluster without encryption
warn[msg] {
  cluster := input.resource.aws_eks_cluster[name]
  not cluster.encryption_config
  msg := sprintf("EKS cluster '%s' should have encryption_config enabled for etcd", [name])
}

# Warn: No backup/snapshot configuration for databases
warn[msg] {
  rds := input.resource.aws_rds_instance[name]
  not rds.backup_retention_period
  msg := sprintf("RDS instance '%s' should define backup_retention_period for disaster recovery", [name])
}

# Warn: ElastiCache without multi-AZ
warn[msg] {
  cache := input.resource.aws_elasticache_cluster[name]
  cache.engine[0] != "memcached"
  not cache.automatic_failover_enabled
  msg := sprintf("ElastiCache cluster '%s' (non-memcached) should enable automatic_failover_enabled for HA", [name])
}

# Deny: CloudTrail not enabled on account (if specified, must be enabled)
warn[msg] {
  trail := input.resource.aws_cloudtrail[name]
  trail.is_enabled[0] != true
  msg := sprintf("CloudTrail '%s' must be enabled", [name])
}
