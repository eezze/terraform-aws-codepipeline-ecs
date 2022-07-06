# -----------------------------------------------------------------------------
# Variables: General
# -----------------------------------------------------------------------------

variable "environment" {
  description = "AWS resource environment/prefix"
}

variable "region" {
  description = "AWS region"
}

variable "resource_tag_name" {
  description = "Resource tag name for cost tracking"
}

variable "codepipeline_module_enabled" {
  type        = bool
  description = "(Optional) Whether to create resources within the module or not. Default is true."
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Variables: CodeBuild
# -----------------------------------------------------------------------------

variable "build_image" {
  type        = string
  default     = "aws/codebuild/standard:4.0"
  description = "Docker image for build environment, e.g. 'aws/codebuild/standard:2.0' or 'aws/codebuild/eb-nodejs-6.10.0-amazonlinux-64:4.0.0'. For more info: http://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref.html"
}

variable "build_compute_type" {
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
  description = "Instance type of the build instance"
}

variable "build_timeout" {
  default     = 5
  description = "How long in minutes, from 5 to 480 (8 hours), for AWS CodeBuild to wait until timing out any related build that does not get marked as completed"
}

variable "container_buildspec" {
  type    = string
  default = "Build YML specification file"
}

variable "extract_cfn_buildspec" {
  type    = string
  default = "Build YML specification file to create the CloudFormation container deploy"
}

variable "badge_enabled" {
  type        = bool
  default     = false
  description = "Generates a publicly-accessible URL for the projects build badge. Available as badge_url attribute when enabled"
}

variable "privileged_mode" {
  type        = bool
  default     = false
  description = "(Optional) If set to true, enables running the Docker daemon inside a Docker container on the CodeBuild instance. Used when building Docker images"
}

variable "container_build_environment_variables" {
  type = list(object({
    name  = string
    value = string
    type  = string
  }))
  default     = []
  description = "Additional environment variables for the build process. The type of environment variable. Valid values: PARAMETER_STORE, PLAINTEXT, and SECRETS_MANAGER."
}

variable "cfn_extract_environment_variables" {
  type = list(object({
    name  = string
    value = string
    type  = string
  }))
  default     = []
  description = "Additional environment variables for the build process. The type of environment variable. Valid values: PARAMETER_STORE, PLAINTEXT, and SECRETS_MANAGER."
}

# -----------------------------------------------------------------------------
# Variables: CodePipeline
# -----------------------------------------------------------------------------
variable "git_owner" {
  type        = string
  description = "Github username"
}

variable "git_repo" {
  type        = string
  description = "Github repository name"
}

variable "git_branch" {
  type        = string
  description = "Github branch name"
  default     = "master"
}

variable "git_provider_type" {
  description = "Codestar connections support; GitHub, Bitbucket"
  default     = "GitHub"
}

variable "poll_source_changes" {
  type        = string
  default     = "false"
  description = "Periodically check the location of your source content and run the pipeline if changes are detected"
}

variable "ecr_repository_name" {
  type        = string
  description = "AWS ECR Repository configured Name"
}

variable "ecr_arn" {
  type        = string
  description = "AWS ECR Repository ARN"
}

variable "SSH_PRIVATE_KEY" {
  type        = string
  description = "Git SSH Private Key loaded in from environment variables only(!). This will expose your SSH key to encrypted AWS S3 terraform state file storage."
}
