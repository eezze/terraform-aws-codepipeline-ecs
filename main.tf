locals {
  resource_name = "${var.environment}-${var.git_repo}"

  tags = var.tags

  ssh_key_object = {
    name  = "SSH_PRIVATE_KEY"
    type  = "PLAINTEXT"
    value = var.SSH_PRIVATE_KEY
  }

  # If a Git SSH Key is provided, add it to the environment variables for the container builds
  # Note: 
  # This will expose your SSH key to the Terraform state file, make sure it's encrypted!
  # This will also expose the SSH key in the CodeBuild logs and execution, better solution is to use PARAMETER_STORE and retrieve it inside the build.
  container_build_vars = var.SSH_PRIVATE_KEY == "" ? var.container_build_environment_variables : concat(local.ssh_key_object, var.container_build_environment_variables)
  extract_build_vars = var.SSH_PRIVATE_KEY == "" ? var.cfn_extract_environment_variables : concat(local.ssh_key_object, var.cfn_extract_environment_variables)
}

# -----------------------------------------------------------------------------
# Resources: Random string
# -----------------------------------------------------------------------------
resource "random_string" "postfix" {
  length  = 6
  numeric = false
  upper   = false
  special = false
  lower   = true
}

# -----------------------------------------------------------------------------
# Resources: CodePipeline
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "artifact_store" {
  count = var.codepipeline_module_enabled ? 1 : 0

  bucket        = "${local.resource_name}-codepipeline-artifacts-${random_string.postfix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "_" {
  count = var.codepipeline_module_enabled ? 1 : 0

  bucket = try(one(aws_s3_bucket.artifact_store.*.id), "")

  rule {
    id     = "lifecycle_rule_codepipeline_expiration"
    status = "Enabled"
    expiration {
      days = 5
    }
  }
}

resource "aws_s3_bucket_acl" "_" {
  count = var.codepipeline_module_enabled ? 1 : 0

  bucket = try(one(aws_s3_bucket.artifact_store.*.id), "")

  acl = "private"
}

module "iam_codepipeline" {
  source = "github.com/rpstreef/tf-iam?ref=v1.2"

  environment       = var.environment
  region            = var.region
  resource_tag_name = var.resource_tag_name

  iam_module_enabled = var.codepipeline_module_enabled

  assume_role_policy = file("${path.module}/policies/codepipeline-assume-role.json")
  template           = file("${path.module}/policies/codepipeline-policy.json")
  role_name          = "codepipeline-${var.git_repo}-role"
  policy_name        = "codepipeline-${var.git_repo}-policy"

  role_vars = {
    codebuild_project_arn = try(one(module.codebuild_container.*.arn), "")
    s3_bucket_arn         = try(one(aws_s3_bucket.artifact_store.*.arn), "")
    codestar_arn          = try(one(aws_codestarconnections_connection._.*.arn), "")
  }
}

module "iam_cloudformation" {
  source = "github.com/rpstreef/tf-iam?ref=v1.2"

  environment       = var.environment
  region            = var.region
  resource_tag_name = var.resource_tag_name

  iam_module_enabled = var.codepipeline_module_enabled

  assume_role_policy = file("${path.module}/policies/cloudformation-assume-role.json")
  template           = file("${path.module}/policies/cloudformation-policy.json")
  role_name          = "cloudformation-${var.git_repo}-role"
  policy_name        = "cloudformation-${var.git_repo}-policy"

  role_vars = {
    s3_bucket_arn         = try(one(aws_s3_bucket.artifact_store.*.arn), "")
    codepipeline_role_arn = try(module.iam_codepipeline.role_arn, "")
  }
}

# The aws_codestarconnections_connection resource is created in the state PENDING. 
# Authentication with the connection provider must be completed in the AWS Console.
resource "aws_codestarconnections_connection" "_" {
  count = var.codepipeline_module_enabled ? 1 : 0

  name          = "${local.resource_name}-cs"
  provider_type = var.git_provider_type
}

resource "aws_codepipeline" "_" {
  count = var.codepipeline_module_enabled ? 1 : 0

  name     = "${local.resource_name}-codepipeline"
  role_arn = try(module.iam_codepipeline.role_arn, "")

  artifact_store {
    location = one(aws_s3_bucket.artifact_store.*.bucket)
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["Source"]

      configuration = {
        ConnectionArn    = one(aws_codestarconnections_connection._.*.arn)
        FullRepositoryId = "${var.git_owner}/${var.git_repo}"
        BranchName       = var.git_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildContainerImage"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["Source"]
      output_artifacts = ["ImageBuild"]

      configuration = {
        ProjectName = one(module.codebuild_container.*.name)
      }
    }
  }

  stage {
    name = "Compose2Cloudformation"

    action {
      name             = "ExtractCFN"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["Source"]
      output_artifacts = ["ExtractedCfn"]

      configuration = {
        ProjectName = one(module.codebuild_extract_cfn.*.name)
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      run_order = 1

      name            = "CreateChangeSet"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      version         = "1"
      input_artifacts = ["ExtractedCfn"]

      configuration = {
        ActionMode            = "CHANGE_SET_REPLACE"
        StackName             = "${local.resource_name}-stack"
        ChangeSetName         = "${local.resource_name}-changeset"
        RoleArn               = try(module.iam_cloudformation.role_arn, "")
        TemplatePath          = "ExtractedCfn::cloudformation.yml"
        TemplateConfiguration = "ExtractedCfn::configuration.json"
        Capabilities          = "CAPABILITY_IAM,CAPABILITY_AUTO_EXPAND"
      }
    }

    action {
      run_order = 2

      name     = "ExecuteChangeSet"
      category = "Deploy"
      owner    = "AWS"
      provider = "CloudFormation"
      version  = "1"

      configuration = {
        ActionMode     = "CHANGE_SET_EXECUTE"
        Capabilities   = "CAPABILITY_IAM,CAPABILITY_AUTO_EXPAND"
        OutputFileName = "ChangeSetExecuteOutput.json"
        StackName      = "${local.resource_name}-stack"
        ChangeSetName  = "${local.resource_name}-changeset"
      }
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [stage[0].action[0].configuration]
  }
}

# -----------------------------------------------------------------------------
# Resources: CodeBuild
# -----------------------------------------------------------------------------

module "codebuild_container" {
  source = "./codebuild"

  resource_tag_name = var.resource_tag_name
  environment       = var.environment
  region            = var.region

  tags = var.tags

  codepipeline_module_enabled = var.codepipeline_module_enabled

  git_repo = var.git_repo

  build_image = var.build_image
  buildspec   = var.container_buildspec

  environment_variable_map = local.container_build_vars
  s3_artifact_store_arn    = try(one(aws_s3_bucket.artifact_store.*.arn), "")
  s3_artifact_store_bucket = one(aws_s3_bucket.artifact_store.*.bucket)
  ecr_arn                  = var.ecr_arn
}

module "codebuild_extract_cfn" {
  source = "./codebuild"

  resource_tag_name = var.resource_tag_name
  environment       = var.environment
  region            = var.region

  tags = var.tags

  codepipeline_module_enabled = var.codepipeline_module_enabled

  git_repo = var.git_repo

  build_image = var.build_image
  buildspec   = var.extract_cfn_buildspec

  environment_variable_map = local.extract_build_vars
  s3_artifact_store_arn    = try(one(aws_s3_bucket.artifact_store.*.arn), "")
  s3_artifact_store_bucket = one(aws_s3_bucket.artifact_store.*.bucket)
  ecr_arn                  = var.ecr_arn
}
