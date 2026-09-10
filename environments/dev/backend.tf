terraform {
  backend "s3" {
    bucket       = "aws-ha-web-app-terraform-state-final-shot"
    key          = "aws-ha-web-app/dev/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}