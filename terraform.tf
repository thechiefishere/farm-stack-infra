terraform {
  backend "s3" {
    bucket = "john-terraform-state-bucket"
    key    = "terraform/"
    region = "us-east-1"
    dynamodb_table = "terraform-state-locks"
  }
}
