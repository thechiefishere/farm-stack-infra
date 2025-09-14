data "aws_ssm_parameter" "john_github_token" {
  name = "john-github-token"
}

data "aws_ssm_parameter" "john_key" {
  name = "john-private-key"
}