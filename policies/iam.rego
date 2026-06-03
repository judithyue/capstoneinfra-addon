# iam.rego - Enforce IAM best practices
package terraform

# Deny: IAM policy with "*" resource and "*" action (admin access)
deny[msg] {
  policy := input.resource.aws_iam_policy[name]
  stmt := policy.policy[0].Statement[_]
  stmt.Action == "*"
  stmt.Resource == "*"
  stmt.Effect == "Allow"
  msg := sprintf("IAM policy '%s' grants unrestricted admin access (Action: *, Resource: *) — use least privilege", [name])
}

# Warn: IAM policy with overly broad actions
warn[msg] {
  policy := input.resource.aws_iam_policy[name]
  stmt := policy.policy[0].Statement[_]
  actions := stmt.Action
  is_array(actions)
  action := actions[_]
  contains(action, "*")
  action != "*"
  msg := sprintf("IAM policy '%s' has wildcard action '%s' — consider using specific actions for least privilege", [name, action])
}

# Warn: IAM user with access keys (prefer roles and temporary credentials)
warn[msg] {
  user := input.resource.aws_iam_user[name]
  input.resource.aws_iam_access_key[_]
  msg := sprintf("IAM user '%s' has access keys — prefer using roles with temporary credentials (STS)", [name])
}

# Deny: Root account used directly (should use IAM users/roles)
warn[msg] {
  input.resource.aws_iam_user_policy_attachment[name]
  msg := sprintf("Avoid using root account — always use IAM users or roles with appropriate permissions")
}

# Warn: IAM role with no trust relationship (cannot be assumed)
warn[msg] {
  role := input.resource.aws_iam_role[name]
  not role.assume_role_policy
  msg := sprintf("IAM role '%s' has no assume_role_policy — it cannot be assumed by any principal", [name])
}

# Warn: EKS cluster role missing required policy
warn[msg] {
  cluster := input.resource.aws_eks_cluster[name]
  role_arn := cluster.role_arn[0]
  not contains(role_arn, "EKSClusterRole")
  msg := sprintf("EKS cluster '%s' role may be missing AmazonEKSClusterPolicy — ensure it is attached", [name])
}

# Warn: Node group role missing required policies
warn[msg] {
  nodegroup := input.resource.aws_eks_node_group[name]
  role_arn := nodegroup.node_role_arn[0]
  not contains(role_arn, "EKSNodeGroupRole")
  msg := sprintf("EKS node group '%s' role may be missing required node policies (EKSWorkerNodePolicy, EC2ContainerRegistry, CNI)", [name])
}

# Deny: IAM policy attached to group with administrative access
warn[msg] {
  policy_attachment := input.resource.aws_iam_group_policy_attachment[name]
  policy_arn := policy_attachment.policy_arn[0]
  contains(policy_arn, "AdministratorAccess")
  msg := sprintf("IAM group '%s' has AdministratorAccess policy attached — use least privilege roles instead", [name])
}

# Warn: S3 bucket policy allowing unrestricted public access
warn[msg] {
  bucket_policy := input.resource.aws_s3_bucket_policy[name]
  policy := bucket_policy.policy[0]
  stmt := policy.Statement[_]
  stmt.Principal == "*"
  msg := sprintf("S3 bucket policy '%s' allows unrestricted public access — restrict to specific principals", [name])
}
