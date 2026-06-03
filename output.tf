output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.custom_vpc.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private_subnets[*].id
}

output "nat_gateway_ips" {
  description = "The public IP addresses of the NAT Gateways"
  value       = aws_eip.elastic_ip[*].public_ip
}

output "external_dns_iam_role_arn" {
  description = "The ARN of the IAM role to pass into your Helm values file"
  value       = aws_iam_role.external_dns_role.arn
}

output "eks_cluster_name" {
  description = "The dynamically resolved name of the EKS cluster"
  value       = aws_eks_cluster.eks-cluster.name
}

output "aws_lb_controller_role_arn" {
  value = aws_iam_role.aws_lb_controller_role.arn
}
# 
/*
output "eks_connect_command" {
  description = "Command to configure kubectl to connect to the EKS cluster"
  value       = "aws eks --region ap-southeast-1 update-kubeconfig --name ${var.cluster_name}"
}*/