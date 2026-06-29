terraform {
  backend "s3" {
    bucket         = "mine-mightycapstone-terraform-state"
    key            = "state/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "mine-mightycapstone-terraform-locks"
    encrypt        = true
  }
}
