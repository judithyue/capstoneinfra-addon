variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "naming_prefix" {
  type = string
}

variable "cluster_config" {
  type = object({
    name    = string
    version = string
  })
}

variable "ecr_config" {
  type = object({
    repo_name            = string
    image_tag_mutability = string
    force_delete         = bool
    scan_on_push         = bool
  })
}
variable "scan_on_push" {
  type    = bool
  default = true
}

variable "common_tags" {
  type = map(string)
}

variable "networking" {
  type = object({
    cidr_block      = string
    azs             = list(string)
    public_subnets  = list(string)
    private_subnets = list(string)
    nat_gateways    = bool
  })
}

variable "security_groups" {
  type = list(object({
    name        = string
    description = string
    ingress = list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
    egress = list(object({
      description = string
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_blocks = list(string)
    }))
  }))
}

variable "node_groups" {
  type = list(any) # simplified for now to keep it clean
}

variable "addons" {
  type = map(any)
}