################################################################################
# NETWORKING (VPC & SUBNETS)
################################################################################

resource "aws_vpc" "custom_vpc" {
  # checkov:skip=CKV2_AWS_11:VPC flow logs disabled to control lab costs
  # checkov:skip=CKV2_AWS_12:Default SG rule skipped for testing
  cidr_block = var.networking.cidr_block

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-vpc"
  })
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.networking.public_subnets)
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = var.networking.public_subnets[count.index]
  availability_zone       = var.networking.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name                                               = "${var.naming_prefix}-public-subnet-${count.index}"
    "kubernetes.io/role/elb"                           = "1"
    "kubernetes.io/cluster/${var.cluster_config.name}" = "shared"
    "elbv2.k8s.aws/cluster/${var.cluster_config.name}" = "owned"
  })
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.networking.private_subnets)
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = var.networking.private_subnets[count.index]
  availability_zone = var.networking.azs[count.index]

  tags = merge(var.common_tags, {
    Name                                               = "${var.naming_prefix}-private-subnet-${count.index}"
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/${var.cluster_config.name}" = "shared"
    "elbv2.k8s.aws/cluster/${var.cluster_config.name}" = "owned"
  })
}

################################################################################
# GATEWAYS & ROUTING
################################################################################

resource "aws_internet_gateway" "i_gateway" {
  vpc_id = aws_vpc.custom_vpc.id
  tags   = merge(var.common_tags, { Name = "${var.naming_prefix}-igw" })
}
resource "aws_eip" "elastic_ip" {
  count      = var.networking.nat_gateways ? length(var.networking.public_subnets) : 0
  depends_on = [aws_internet_gateway.i_gateway]

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "nats" {
  count         = var.networking.nat_gateways ? length(var.networking.public_subnets) : 0
  subnet_id     = aws_subnet.public_subnets[count.index].id
  allocation_id = aws_eip.elastic_ip[count.index].id
  tags          = merge(var.common_tags, { Name = "${var.naming_prefix}-nat-${count.index}" })
}

resource "aws_route_table" "public_table" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-public-route-table"
  })
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.i_gateway.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_table.id
}

resource "aws_route_table" "private_tables" {
  count  = length(var.networking.private_subnets)
  vpc_id = aws_vpc.custom_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-private-route-table-${count.index}"
  })
}

resource "aws_route" "private_nat_access" {
  count                  = var.networking.nat_gateways ? length(var.networking.private_subnets) : 0
  route_table_id         = aws_route_table.private_tables[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nats[count.index].id
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_tables[count.index].id
}

################################################################################
# SECURITY GROUPS (The "DRY" Factory)
################################################################################

resource "aws_security_group" "sec_groups" {
  for_each    = { for sec in var.security_groups : sec.name => sec }
  name        = "${var.naming_prefix}-${each.value.name}"
  description = each.value.description
  vpc_id      = aws_vpc.custom_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-${each.value.name}-sg"
  })

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = each.value.egress
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}

################################################################################
# IAM ROLES (EKS & NODES)
################################################################################

resource "aws_iam_role" "EKSClusterRole" {
  name = "${var.naming_prefix}-EKSClusterRole"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "eks.amazonaws.com" } }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-EKSClusterRole"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.EKSClusterRole.name
}

resource "aws_iam_role" "NodeGroupRole" {
  name = "${var.naming_prefix}-EKSNodeGroupRole"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-EKSNodeGroupRole"
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ])
  policy_arn = each.value
  role       = aws_iam_role.NodeGroupRole.name
}

################################################################################
# EKS CLUSTER & NODE GROUPS
################################################################################
resource "aws_eks_cluster" "eks-cluster" {
  name     = var.cluster_config.name
  role_arn = aws_iam_role.EKSClusterRole.arn
  version  = var.cluster_config.version

  tags = merge(var.common_tags, {
    Name = var.cluster_config.name
  })

  vpc_config {
    # DIRECT REFERENCE to your Subnets and Sec Groups
    subnet_ids         = flatten([aws_subnet.public_subnets[*].id, aws_subnet.private_subnets[*].id])
    security_group_ids = [for sg in aws_security_group.sec_groups : sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.AmazonEKSClusterPolicy]
}

resource "aws_eks_node_group" "node-ec2" {
  for_each        = { for node_group in var.node_groups : node_group.name => node_group }
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "${var.naming_prefix}-${each.value.name}"
  node_role_arn   = aws_iam_role.NodeGroupRole.arn
  subnet_ids      = aws_subnet.private_subnets[*].id

  tags = merge(var.common_tags, {
    Name         = "${var.naming_prefix}-${each.value.name}-nodegroup"
    PipelineTest = "kickstart-run-02" # ADD THIS LINE TO FORCE A REAL DEPLOYMENT TEST
  })

  scaling_config {
    desired_size = each.value.scaling_config.desired_size
    max_size     = each.value.scaling_config.max_size
    min_size     = each.value.scaling_config.min_size
  }

  ami_type       = each.value.ami_type
  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  disk_size      = each.value.disk_size

  depends_on = [aws_iam_role_policy_attachment.node_policies]
}

################################################################################
# ADDONS & OIDC
################################################################################

# Fetch the TLS certificate from the EKS OIDC issuer URL
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  url             = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-eks-oidc-provider"
  })
}

resource "aws_eks_addon" "addons" {
  for_each                    = var.addons
  cluster_name                = aws_eks_cluster.eks-cluster.name
  addon_name                  = each.value.name
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [aws_eks_node_group.node-ec2]
}

################################################################################
# EXTERNAL-DNS IAM CONFIGURATION (IRSA)
################################################################################

# Define the Route 53 Access Policy
data "aws_route53_zone" "selected" {
  name         = "sctp-sandbox.com"
  private_zone = false
}

resource "aws_iam_policy" "external_dns_policy" {
  name        = "${var.naming_prefix}-AllowExternalDNSUpdates"
  description = "Allows EKS ExternalDNS pod to manage Route 53 resource record sets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.selected.zone_id}"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones" #This API CANNOT be restricted by AWS to a specific zone ARN
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-external-dns-policy"
  })
}

# Establish the Trust Relationship with your EKS OIDC Provider
data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      # This binds the role strictly to the 'external-dns' service account name in the 'kube-system' namespace
      values = ["system:serviceaccount:kube-system:external-dns"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_oidc_provider.arn]
      type        = "Federated"
    }
  }
}

# Create the IAM Role for the Service Account
resource "aws_iam_role" "external_dns_role" {
  name               = "${var.naming_prefix}-EKSExternalDNSRole"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-external-dns-role"
  })
}

# Attach the Policy to the Role
resource "aws_iam_role_policy_attachment" "external_dns_attach" {
  policy_arn = aws_iam_policy.external_dns_policy.arn
  role       = aws_iam_role.external_dns_role.name
}

################################################################################
# OUTPUTS
################################################################################
/*
output "external_dns_iam_role_arn" {
  description = "The ARN of the IAM role to pass into your Helm values file"
  value       = aws_iam_role.external_dns_role.arn
}*/


################################################################################
# aws alb controller
################################################################################

# Download the official AWS Load Balancer Controller IAM Policy document
data "http" "aws_lb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

# Create the IAM Policy in your AWS Account
resource "aws_iam_policy" "aws_lb_controller" {
  name        = "${var.naming_prefix}-AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy for EKS"
  policy      = data.http.aws_lb_controller_policy.response_body
}

# Create the IAM Role Trust Relationship (using existing EKS OIDC setup)
data "aws_iam_policy_document" "aws_lb_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_oidc_provider.arn]
      type        = "Federated"
    }
  }
}

# Create the IAM Role
resource "aws_iam_role" "aws_lb_controller_role" {
  name               = "${var.naming_prefix}-AWSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.aws_lb_assume_role.json
}

# Attach the Policy to the Role
resource "aws_iam_role_policy_attachment" "aws_lb_controller_attach" {
  policy_arn = aws_iam_policy.aws_lb_controller.arn
  role       = aws_iam_role.aws_lb_controller_role.name
}

# Output the ARN so your pipeline can read it dynamically
/*
output "aws_lb_controller_role_arn" {
  value = aws_iam_role.aws_lb_controller_role.arn
}
*/

################################################################################
# ECR
################################################################################
resource "aws_ecr_repository" "ecr" {
  name                 = var.ecr_config.repo_name
  image_tag_mutability = var.ecr_config.image_tag_mutability
  force_delete         = var.ecr_config.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-ecr-repo"
  })
}

################################################################################
# GITHUB ACTIONS OIDC IDENTITY PROVIDER
################################################################################

# Fetch GitHub's OIDC TLS Certificate to verify its identity thumbprint
# Create the OIDC Provider in AWS IAM (note: 1 github provider per AWS account, so this is a one-time setup)
# Look up the EXISTING global GitHub OIDC provider instead of creating a new onedata "aws_iam_openid_connect_provider" "github_provider" {
data "aws_iam_openid_connect_provider" "github_provider" {
  url = "https://token.actions.githubusercontent.com"
}

# Create the dedicated IAM Role your GitHub Actions runner will assume
resource "aws_iam_role" "github_actions_role" {
  name               = "${var.naming_prefix}-GitHubActionsDeploymentRole"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = merge(var.common_tags, {
    Name = "${var.naming_prefix}-github-actions-role"
  })
}

# Define the strict Trust Policy for GitHub Actions
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    # Restricts token validation down to the official GitHub OIDC issuer
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # SECURITY LOCK: Restricts access ONLY to your specific GitHub repository
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Replace YOUR_GITHUB_ORGANIZATION_OR_USERNAME and YOUR_REPO_NAME with your exact setup
      values = ["repo:judithyue/example-voting-app:*"]
    }

    principals {
      identifiers = [data.aws_iam_openid_connect_provider.github_provider.arn]
      type        = "Federated"
    }
  }
}

# Attach Administrative permissions to manage your ECR and EKS environments
resource "aws_iam_role_policy_attachment" "github_ecr_poweruser" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role       = aws_iam_role.github_actions_role.name
}

# Output the exact Role ARN you need to paste into your GitHub Repository Secrets
output "github_actions_role_arn" {
  description = "Save this value into your GitHub secret named AWS_ROLE_TO_ASSUME"
  value       = aws_iam_role.github_actions_role.arn
}

# Create a custom policy allowing GitHub to read EKS Cluster metadata
resource "aws_iam_policy" "github_eks_describe_policy" {
  name        = "${var.naming_prefix}-GitHubEKSDescribePolicy"
  description = "Allows GitHub Actions runner to fetch EKS cluster configurations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = [aws_eks_cluster.eks-cluster.arn]
      }
    ]
  })
}

# Attach it to your existing GitHub Actions IAM role
resource "aws_iam_role_policy_attachment" "github_eks_attach" {
  policy_arn = aws_iam_policy.github_eks_describe_policy.arn
  role       = aws_iam_role.github_actions_role.name
}

# Create an EKS Access Entry linking your GitHub Role to the cluster
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  principal_arn = aws_iam_role.github_actions_role.arn
  type          = "STANDARD"
}

# Grant cluster-admin permissions to that entry
resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name  = aws_eks_cluster.eks-cluster.name
  policy_arn    = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.github_actions_role.arn

  access_scope {
    type = "cluster"
  }
}