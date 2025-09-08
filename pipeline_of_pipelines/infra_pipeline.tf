provider "aws" {
    region = "us-east-1"
}

resource "aws_s3_bucket" "john_infra_codepipeline_artifact_bucket" {
  bucket = "john-infra-codepipeline-artifact-bucket"
}

resource "aws_s3_bucket" "john_terraform_state_bucket" {
  bucket = "john-terraform-state-bucket-005"
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "terraform-locks"
    createdby = "john.toriola@cecureintel.com"
  }
}

resource "aws_iam_role" "john_infra_codepipeline_role" {
  name = "john_infra_codepipeline_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "john_infra_codepipline_role_policy" {
  name        = "john_infra_codepipline_role_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "codebuild:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ssm:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "john_infra_codepipeline_role_policy_attachment" {
  name       = "john_infra_codepipeline_role_policy_attachment"
  roles      = [aws_iam_role.john_infra_codepipeline_role.name]
  policy_arn = aws_iam_policy.john_infra_codepipline_role_policy.arn
}

resource "aws_iam_role" "john_infra_codebuild_role" {
  name = "john_infra_codebuild_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "john_infra_codebuild_role_policy" {
  name        = "john_infra_codebuild_role_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "dynamodb:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ssm:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "*",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "john_infra_codebuild_role_policy_attachment" {
  name       = "john_infra_codebuild_role_policy_attachment"
  roles      = [aws_iam_role.john_infra_codebuild_role.name]
  policy_arn = aws_iam_policy.john_infra_codebuild_role_policy.arn
}

resource "aws_codebuild_project" "john_infra_codebuild_plan" {
  name           = "john_infra_codebuild_plan"
  service_role = aws_iam_role.john_infra_codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }
  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec_plan.yml"
  }
}

resource "aws_codebuild_project" "john_infra_codebuild_apply" {
  name           = "john_infra_codebuild_apply"
  service_role = aws_iam_role.john_infra_codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }
  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec_apply.yml"
  }
}

data "aws_ssm_parameter" "john_infra_github_token" {
  name = "john-github-token"
}

resource "aws_codepipeline" "john_infra_pipeline" {
  name     = "john_infra_infra_pipeline"
  role_arn = aws_iam_role.john_infra_codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.john_infra_codepipeline_artifact_bucket.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "Commit"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner          = "thechiefishere"
        Repo           = "farm-stack-infra"
        Branch         = "main"
        OAuthToken     = data.aws_ssm_parameter.john_infra_github_token.value
      }
    }
  }
  stage {
    name = "Plan"

    action {
      name             = "Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_plan"]
      version          = "1"

      configuration = {
        ProjectName    = aws_codebuild_project.john_infra_codebuild_plan.id
      }
    }
  }

  stage {
    name = "Apply"

    action {
      name             = "Apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_apply"]
      version          = "1"

      configuration = {
        ProjectName    = aws_codebuild_project.john_infra_codebuild_apply.id
      }
    }
  }

}