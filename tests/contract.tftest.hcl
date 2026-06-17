# Contract tests — output surface stays stable across minor + patch versions.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "ap-south-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name                       = "contract-test"
  vpc_id                     = "vpc-00000000000000000"
  subnet_ids                 = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  ingress_security_group_ids = ["sg-00000000000000000"]
  container_image            = "public.ecr.aws/nginx/nginx:1.27-alpine"
  container_port             = 80
}

run "single_service_planned" {
  command = plan
  assert {
    condition     = aws_ecs_service.this.name == "contract-test"
    error_message = "Service name must equal var.name."
  }
}

run "task_family_matches_name" {
  command = plan
  assert {
    condition     = aws_ecs_task_definition.this.family == "contract-test"
    error_message = "Task family must equal var.name."
  }
}

run "cpu_memory_passthrough" {
  command = plan
  assert {
    condition     = aws_ecs_task_definition.this.cpu == "512"
    error_message = "Default cpu must be 512."
  }
  assert {
    condition     = aws_ecs_task_definition.this.memory == "1024"
    error_message = "Default memory must be 1024."
  }
}

run "log_group_naming_stable" {
  command = plan
  assert {
    condition     = aws_cloudwatch_log_group.this.name == "/ecs/contract-test"
    error_message = "Log group must be /ecs/<name>."
  }
}

run "network_config_uses_subnets" {
  command = plan
  assert {
    condition     = length(aws_ecs_service.this.network_configuration[0].subnets) == 2
    error_message = "Service must attach to the supplied subnets."
  }
}

run "desired_count_default_two" {
  command = plan
  assert {
    condition     = aws_ecs_service.this.desired_count == 2
    error_message = "Default desired_count must be 2 (HA)."
  }
}
