# tags.rego - Enforce mandatory tagging standards
package terraform

# Mandatory tags that should be present on all taggable resources
mandatory_tags := ["Name", "Environment", "Owner", "Project", "CostCenter"]

# Taggable resource types
taggable_resources := [
  "aws_vpc",
  "aws_subnet",
  "aws_security_group",
  "aws_instance",
  "aws_rds_instance",
  "aws_s3_bucket",
  "aws_eks_cluster",
  "aws_ecr_repository",
  "aws_iam_role",
  "aws_nat_gateway",
  "aws_eip",
  "aws_internet_gateway",
  "aws_route_table",
  "aws_elasticache_cluster"
]

# Deny: resources missing tags
deny[msg] {
  resource := input.resource[resource_type][name]
  resource_type in taggable_resources
  not resource.tags
  msg := sprintf("Resource '%s.%s' must have tags defined", [resource_type, name])
}

# Deny: resources with tags but missing mandatory tags
deny[msg] {
  resource := input.resource[resource_type][name]
  resource_type in taggable_resources
  resource.tags
  tags := resource.tags[0]
  missing := [tag | tag := mandatory_tags[_]; not tags[tag]]
  count(missing) > 0
  msg := sprintf("Resource '%s.%s' is missing mandatory tags: %v", [resource_type, name, missing])
}

# Warn: tags should not have empty values
warn[msg] {
  resource := input.resource[resource_type][name]
  resource_type in taggable_resources
  resource.tags
  tags := resource.tags[0]
  tag := mandatory_tags[_]
  tags[tag]
  trim_space(tags[tag][0]) == ""
  msg := sprintf("Resource '%s.%s' has empty value for tag '%s'", [resource_type, name, tag])
}
