terraform {
  backend "s3" {
    bucket = "john-terraform-state-bucket"
    key    = "farm-stack/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-state-locks"
  }
}
