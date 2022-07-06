locals {
  resource_name = "${var.environment}-${var.git_repo}"

  tags = var.tags
}
data "aws_iam_policy_document" "policy_codebuild" {
  statement {
    effect = "Allow"
    resources = [
      "*"
    ]
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "iam:PassRole"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning"
    ]
    resources = compact([
      "${try(var.s3_artifact_store_arn, "")}",
      "${try(var.s3_artifact_store_arn, "")}/*",
    ])
  }
  statement {
    effect = "Allow"
    resources = [
      "*"
    ]
    actions = [
      "ecr:GetAuthorizationToken"
    ]
  }
  statement {
    effect = "Allow"
    resources = [
      "${var.ecr_arn}"
    ]
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart"
    ]
  }
}

data "aws_iam_policy_document" "assume_role_codebuild" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "random_string" "postfix" {
  length  = 6
  numeric = false
  upper   = false
  special = false
  lower   = true
}

resource "aws_iam_role" "codebuild" {
  count = var.codepipeline_module_enabled ? 1 : 0

  name = "${local.resource_name}-${random_string.postfix.result}"

  assume_role_policy = one(data.aws_iam_policy_document.assume_role_codebuild.*.json)

  tags = local.tags
}

resource "aws_iam_policy" "_" {
  count = var.codepipeline_module_enabled ? 1 : 0

  name = "${local.resource_name}-${random_string.postfix.result}"

  policy = one(data.aws_iam_policy_document.policy_codebuild.*.json)

  tags = local.tags
}

resource "aws_iam_policy_attachment" "_" {
  count = var.codepipeline_module_enabled ? 1 : 0

  name = "${local.resource_name}-policy-attachement"

  policy_arn = one(aws_iam_policy._.*.arn)
  roles      = [one(aws_iam_role.codebuild.*.name)]
}

resource "aws_codebuild_project" "_" {
  count = var.codepipeline_module_enabled ? 1 : 0

  name          = "${local.resource_name}-codebuild-${random_string.postfix.result}"
  description   = "${local.resource_name}_codebuild_project"
  build_timeout = var.build_timeout
  badge_enabled = var.badge_enabled
  service_role  = one(aws_iam_role.codebuild.*.arn)

  artifacts {
    type           = "CODEPIPELINE"
    namespace_type = "BUILD_ID"
    packaging      = "ZIP"
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = var.privileged_mode

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = try(var.s3_artifact_store_bucket)
    }

    dynamic "environment_variable" {
      for_each = var.environment_variable_map

      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec
  }

  tags = local.tags
}
