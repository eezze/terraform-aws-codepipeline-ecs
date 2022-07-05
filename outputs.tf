locals {
  o_codepipeline = try(aws_codepipeline._[0], {})
}

output "codepipeline" {
  description = "The full `aws_codepipeline` object."
  value       = local.o_codepipeline
}