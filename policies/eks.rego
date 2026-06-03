# eks.rego - Enforce EKS-specific best practices
package terraform

# Deny: EKS cluster without private endpoint disabled (should restrict API access)
warn[msg] {
  cluster := input.resource.aws_eks_cluster[name]
  cluster.endpoint_private_access[0] != true
  msg := sprintf("EKS cluster '%s' should have endpoint_private_access enabled to restrict API access", [name])
}

# Warn: EKS cluster with public endpoint unrestricted
warn[msg] {
  cluster := input.resource.aws_eks_cluster[name]
  cluster.endpoint_public_access[0] == true
  msg := sprintf("EKS cluster '%s' has public endpoint access enabled — consider restricting via public_access_cidrs", [name])
}

# Warn: EKS node group without tags
warn[msg] {
  nodegroup := input.resource.aws_eks_node_group[name]
  not nodegroup.tags
  msg := sprintf("EKS node group '%s' should have tags for cost tracking and lifecycle management", [name])
}

# Warn: EKS node group using outdated AMI type
warn[msg] {
  nodegroup := input.resource.aws_eks_node_group[name]
  ami_type := nodegroup.ami_type[0]
  ami_type in ["WINDOWS_CORE_2016_1909", "WINDOWS_CORE_2019_1909"]
  msg := sprintf("EKS node group '%s' uses outdated AMI type '%s' — use newer AL2, BOTTLEROCKET, or WINDOWS versions", [name, ami_type])
}

# Warn: EKS node group with insufficient minimum nodes
warn[msg] {
  nodegroup := input.resource.aws_eks_node_group[name]
  min_size := nodegroup.scaling_config[0].min_size[0]
  min_size < 1
  msg := sprintf("EKS node group '%s' has min_size < 1 — ensure at least 1 node for application availability", [name])
}

# Warn: EKS node group without capacity type specified (defaults to on-demand)
warn[msg] {
  nodegroup := input.resource.aws_eks_node_group[name]
  not nodegroup.capacity_type
  msg := sprintf("EKS node group '%s' should specify capacity_type (ON_DEMAND or SPOT) for cost optimization", [name])
}

# Warn: OIDC provider without proper thumbprint
warn[msg] {
  oidc := input.resource.aws_iam_openid_connect_provider[name]
  thumbprints := oidc.thumbprint_list[0]
  count(thumbprints) == 0
  msg := sprintf("IAM OIDC provider '%s' has no thumbprints — this may cause authentication failures", [name])
}

# Warn: EKS add-ons not specified (security, networking, monitoring add-ons recommended)
warn[msg] {
  cluster := input.resource.aws_eks_cluster[name]
  not input.resource.aws_eks_addon[_]
  msg := sprintf("EKS cluster '%s' has no add-ons enabled — consider adding VPC-CNI, CoreDNS, kube-proxy", [name])
}

# Warn: EKS cluster with multiple node groups using same subnet (potential congestion)
warn[msg] {
  cluster := input.resource.aws_eks_cluster[name]
  msg := sprintf("EKS cluster '%s' — ensure node groups span multiple availability zones and subnets for resilience", [name])
}
