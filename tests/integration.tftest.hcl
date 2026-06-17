# Integration tests — apply + assert + destroy.
# Requires real AWS credentials AND pre-existing networking (VPC + private subnets
# + an SG to allow as ingress source). Triggered via workflow_dispatch on integration.yml.

provider "aws" {
  region = "ap-south-1"
}

variables {
  name = "integ-test-ecs"

  vpc_id                     = ""
  subnet_ids                 = []
  ingress_security_group_ids = []

  # A tiny always-available public image so the task can actually pull + run.
  container_image = "public.ecr.aws/nginx/nginx:1.27-alpine"
  container_port  = 80
  cpu             = 256
  memory          = 512

  desired_count = 1

  tags = { Environment = "integration-test", Ephemeral = "true" }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_ecs_cluster.this[0].arn != ""
    error_message = "Cluster must be created."
  }
  assert {
    condition     = aws_ecs_service.this.id != ""
    error_message = "Service must be created."
  }
  assert {
    condition     = aws_ecs_task_definition.this.arn != ""
    error_message = "Task definition must be registered."
  }
  assert {
    condition     = aws_ecs_service.this.enable_execute_command == false
    error_message = "ECS Exec must be off."
  }
}
