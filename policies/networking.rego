# networking.rego - Enforce networking best practices
package terraform

# Deny: VPC without enabling DNS hostnames (needed for EKS, RDS, etc.)
warn[msg] {
  vpc := input.resource.aws_vpc[name]
  vpc.enable_dns_hostnames[0] != true
  msg := sprintf("VPC '%s' should enable DNS hostnames (enable_dns_hostnames = true)", [name])
}

# Deny: Subnets in VPC without route tables associated
warn[msg] {
  subnet := input.resource.aws_subnet[name]
  not input.resource.aws_route_table_association[_]
  msg := sprintf("Subnet '%s' should be associated with a route table for proper routing", [name])
}

# Deny: VPC without NAT Gateway for private subnets
warn[msg] {
  vpc := input.resource.aws_vpc[name]
  has_private_subnets := [s | input.resource.aws_subnet[s].vpc_id == vpc.id; not input.resource.aws_subnet[s].map_public_ip_on_launch[0]]
  count(has_private_subnets) > 0
  not input.resource.aws_nat_gateway[_]
  msg := sprintf("VPC '%s' has private subnets but no NAT Gateway defined for egress", [name])
}

# Deny: Security group with no rules (should be removed)
warn[msg] {
  sg := input.resource.aws_security_group[name]
  not sg.ingress
  not sg.egress
  msg := sprintf("Security group '%s' has no ingress or egress rules — consider removing or adding rules", [name])
}

# Warn: Default security group usage (should create explicit SGs)
warn[msg] {
  instance := input.resource.aws_instance[name]
  not instance.security_groups
  not instance.vpc_security_group_ids
  msg := sprintf("EC2 instance '%s' is using default security group — create and assign explicit security group", [name])
}

# Deny: Network ACL allowing unrestricted access on all ports
warn[msg] {
  nacl_rule := input.resource.aws_network_acl_rule[name]
  nacl_rule.from_port[0] == 0
  nacl_rule.to_port[0] == 65535
  nacl_rule.cidr_block[0] == "0.0.0.0/0"
  nacl_rule.egress[0] != true
  msg := sprintf("Network ACL rule '%s' allows unrestricted inbound access on all ports", [name])
}

# Warn: VPC Peering without route table updates (assume routes should be configured)
warn[msg] {
  peering := input.resource.aws_vpc_peering_connection[name]
  msg := sprintf("VPC Peering connection '%s' created — ensure route tables are updated to use this peering connection", [name])
}

# Warn: No flow logs on VPC
warn[msg] {
  vpc := input.resource.aws_vpc[name]
  not input.resource.aws_flow_log[_]
  msg := sprintf("VPC '%s' should have VPC Flow Logs enabled for network monitoring and compliance", [name])
}
