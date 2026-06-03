output "backend_bucket" {
  description = "Name of the S3 bucket used for Terraform remote state."
  value       = aws_s3_bucket.remote_state.bucket
}

output "lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  value       = aws_dynamodb_table.terraform_locks.name
}
