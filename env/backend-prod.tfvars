bucket         = "hq-mightycapstone-terraform-state"
key            = "state/prod/hq-terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "hq-mightycapstone-terraform-locks"
encrypt        = true
