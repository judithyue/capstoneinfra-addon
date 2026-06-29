variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "backend_bucket" {
  type    = string
  default = "mine-mightycapstone-terraform-state"
}

variable "lock_table_name" {
  type    = string
  default = "mine-mightycapstone-terraform-locks"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project = "mine-venture"
  }
}
