terraform {
  backend "s3" {
    bucket         = "adhi-cloudshop-terraform-state"
    key            = "stage/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cloudshop-terraform-locks"
  }
}
