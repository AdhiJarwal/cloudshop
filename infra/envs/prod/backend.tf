terraform {
  backend "s3" {
    bucket         = "cloudshop-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cloudshop-terraform-locks"
  }
}
