aws_region    = "ap-southeast-1"
naming_prefix = "mine-dev"

cluster_config = {
  name    = "mine-eks-cluster-dev"
  version = "1.32"
}

ecr_config = {
  repo_name            = "mine-eks-repo-dev"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  scan_on_push         = true
}

common_tags = {
  Project     = "mine-venture"
  Stage       = "dev"
  Environment = "dev"
}

networking = {
  cidr_block      = "10.0.0.0/16"
  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  nat_gateways    = true
}

security_groups = [
  {
    name        = "mine-eks-nodes-sg"
    description = "Security group for worker nodes"
    ingress     = [{ description = "Internal", from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["10.0.0.0/16"] }]
    egress      = [{ description = "All Out", from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }]
  },
  {
    name        = "mine-public-alb-sg"
    description = "Security group for the Load Balancer"
    ingress     = [{ description = "HTTP", from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }]
    egress      = [{ description = "To Nodes", from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["10.0.0.0/16"] }]
  }
]

node_groups = [
  {
    name           = "mine-standard-nodes"
    instance_types = ["t3.micro"]
    capacity_type  = "SPOT"
    scaling_config = { desired_size = 4, max_size = 6, min_size = 1 }
    disk_size      = 20
    ami_type       = "AL2_x86_64"
  }
]

addons = {
  vpc-cni = { name = "vpc-cni" }
  coredns = { name = "coredns" }
}
