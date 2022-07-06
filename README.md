# AWS CodePipeline for ECS with Docker-Compose AWS Extensions

## Example module usage

Example:

```terraform


      [
        {
          "name" : "AWS_ACCOUNT_ID",
          "value" : "${data.aws_caller_identity.current.account_id}",
          "type" : "PLAINTEXT"
        },
        {
          "name" : "IMAGE_URI",
          "value" : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_caller_identity.current.account_id}.amazonaws.com/${var.ecr_repository_name}",
          "type" : "PLAINTEXT"
        },
        {
          "name" : "IMAGE_TAG",
          "value" : "#{codepipeline.PipelineExecutionId}",
          "type" : "PLAINTEXT"
        },
        {
          "name": "AWS_ECS_CLUSTER",
          "value": "${var.ecs_cluster_name}",
          "type": "PLAINTEXT"
        },
        {
          "name": "AWS_VPC",
          "value": "${var.vpc_name}",
          "type": "PLAINTEXT"
        },
        {
          "name": "AWS_ELB",
          "value": "${var.elb_name}",
          "type": "PLAINTEXT"
        }
      ]
```

## In depth:

To get AWS credentials inside an contianer build
https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html

```bash
curl 169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
```

which yields:

```json
{
    "AccessKeyId": "ACCESS_KEY_ID",
    "Expiration": "EXPIRATION_DATE",
    "RoleArn": "TASK_ROLE_ARN",
    "SecretAccessKey": "SECRET_ACCESS_KEY",
    "Token": "SECURITY_TOKEN_STRING"
}
```

In case other Github repositories need to be accessed from the Dockerfile, we can set the SSH key as a variable, run `setSshKeyToEnv.sh` to set the `SSH_PRIVATE_KEY` terraform variable via the environment variables. We definitely do not want to store these in the `tfvars` as plaintext, however this will store this key in the Terraform state file, ensure it's properly encrypted.


## Sources:


https://github.com/aws-containers/demo-app-for-docker-compose/blob/main/pipeline/cloudformation.yaml

https://aws.amazon.com/blogs/containers/deploy-applications-on-amazon-ecs-using-docker-compose/

https://aws.amazon.com/blogs/containers/automated-software-delivery-using-docker-compose-and-amazon-ecs/

https://www.docker.com/blog/docker-compose-from-local-to-amazon-ecs/
