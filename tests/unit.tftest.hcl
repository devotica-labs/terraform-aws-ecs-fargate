# Plan-only unit tests — no AWS credentials required.

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
  name                       = "unit-test"
  vpc_id                     = "vpc-00000000000000000"
  subnet_ids                 = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  ingress_security_group_ids = ["sg-00000000000000000"]
  container_image            = "public.ecr.aws/nginx/nginx:1.27-alpine"
  container_port             = 80
  tags                       = { Environment = "unit-test" }
}

run "cluster_created_by_default" {
  command = plan
  assert {
    condition     = length(aws_ecs_cluster.this) == 1
    error_message = "Cluster must be created when create_cluster = true (default)."
  }
  assert {
    condition     = aws_ecs_cluster.this[0].setting != null
    error_message = "Container Insights setting block must be present."
  }
}

run "byo_cluster_skips_creation" {
  command = plan
  variables {
    create_cluster = false
    cluster_arn    = "arn:aws:ecs:ap-south-1:123456789012:cluster/existing"
  }
  assert {
    condition     = length(aws_ecs_cluster.this) == 0
    error_message = "No cluster should be created when create_cluster = false."
  }
}

run "task_def_is_fargate_awsvpc" {
  command = plan
  assert {
    condition     = contains(aws_ecs_task_definition.this.requires_compatibilities, "FARGATE")
    error_message = "Task definition must require FARGATE."
  }
  assert {
    condition     = aws_ecs_task_definition.this.network_mode == "awsvpc"
    error_message = "Fargate requires awsvpc network mode."
  }
}

run "execution_and_task_roles_created_by_default" {
  command = plan
  assert {
    condition     = length(aws_iam_role.execution) == 1
    error_message = "Execution role must be created when no ARN supplied."
  }
  assert {
    condition     = length(aws_iam_role.task) == 1
    error_message = "Task role must be created when no ARN supplied."
  }
}

run "supplied_role_arns_skip_creation" {
  command = plan
  variables {
    task_execution_role_arn = "arn:aws:iam::123456789012:role/my-exec"
    task_role_arn           = "arn:aws:iam::123456789012:role/my-task"
  }
  assert {
    condition     = length(aws_iam_role.execution) == 0
    error_message = "Execution role must NOT be created when an ARN is supplied."
  }
  assert {
    condition     = length(aws_iam_role.task) == 0
    error_message = "Task role must NOT be created when an ARN is supplied."
  }
}

run "service_sg_created_by_default" {
  command = plan
  assert {
    condition     = length(aws_security_group.service) == 1
    error_message = "Service SG must be created when no BYO SGs supplied."
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_sources) == 1
    error_message = "One ingress rule per source SG expected."
  }
}

run "byo_sg_skips_creation" {
  command = plan
  variables {
    service_security_group_ids = ["sg-0byob0byob0byob00"]
  }
  assert {
    condition     = length(aws_security_group.service) == 0
    error_message = "No service SG should be created when BYO SGs supplied."
  }
}

run "assign_public_ip_false_by_default" {
  command = plan
  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "assign_public_ip must default to false (private networking)."
  }
}

run "execute_command_off_by_default" {
  command = plan
  assert {
    condition     = aws_ecs_service.this.enable_execute_command == false
    error_message = "ECS Exec must be off by default."
  }
}

run "no_alb_attachment_by_default" {
  command = plan
  assert {
    condition     = length(aws_ecs_service.this.load_balancer) == 0
    error_message = "Service must not attach to an ALB when no target group ARN given."
  }
}

run "alb_attachment_when_target_group_set" {
  command = plan
  variables {
    alb_target_group_arn = "arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/tg/0123456789abcdef"
  }
  assert {
    condition     = length(aws_ecs_service.this.load_balancer) == 1
    error_message = "Service must attach to the ALB target group when supplied."
  }
}

run "log_group_unencrypted_by_default" {
  command = plan
  assert {
    condition     = aws_cloudwatch_log_group.this.kms_key_id == null
    error_message = "Log group should use default encryption when no KMS key supplied."
  }
}

run "log_group_kms_encrypted_when_key_set" {
  command = plan
  variables {
    log_kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/abc"
  }
  assert {
    condition     = aws_cloudwatch_log_group.this.kms_key_id == "arn:aws:kms:ap-south-1:123456789012:key/abc"
    error_message = "Log group must use the supplied KMS key."
  }
}

run "autoscaling_off_by_default" {
  command = plan
  assert {
    condition     = length(aws_appautoscaling_target.this) == 0
    error_message = "No autoscaling target when disabled."
  }
}

run "autoscaling_cpu_only_when_memory_target_zero" {
  command = plan
  variables {
    enable_autoscaling        = true
    autoscaling_cpu_target    = 70
    autoscaling_memory_target = 0
  }
  assert {
    condition     = length(aws_appautoscaling_target.this) == 1
    error_message = "Autoscaling target must exist when enabled."
  }
  assert {
    condition     = length(aws_appautoscaling_policy.cpu) == 1
    error_message = "CPU policy expected when cpu_target > 0."
  }
  assert {
    condition     = length(aws_appautoscaling_policy.memory) == 0
    error_message = "Memory policy must NOT exist when memory_target = 0."
  }
}

run "tags_merged" {
  command = plan
  assert {
    condition     = aws_ecs_service.this.tags["Module"] == "terraform-aws-ecs-fargate"
    error_message = "Module-default tag must be merged."
  }
}
