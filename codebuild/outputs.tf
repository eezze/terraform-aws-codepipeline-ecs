output "name" {
  value = try(one(aws_codebuild_project._.*.name), "")
}

output "arn" {
  value = try(one(aws_codebuild_project._.*.arn), "")
}