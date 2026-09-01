variable "aws_region" {
  description = "AWS region where the state bucket will be created"
  type        = string
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}