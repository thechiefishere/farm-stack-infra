terraform {
  backend "s3" {
    bucket = "john-terraform-state-bucket"
    key    = "farm-stack/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
  }
}
