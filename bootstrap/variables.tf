variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "backend_bucket" {
  type    = string
  default = "hq-mightycapstone-terraform-state"
}
  
variable "lock_table_name" {
  type    = string
  default = "hq-mightycapstone-terraform-locks"
}

variable "common_tags" {
  type = map(string)
  default = {
    Project = "hq-venture"
    Stage   = "Dev"
  }
}
