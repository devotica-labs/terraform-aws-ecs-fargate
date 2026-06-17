# ---------------------------------------------------------------------------
# ECS cluster — created unless the caller brings an existing one.
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  count = var.create_cluster ? 1 : 0

  name = var.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = local.common_tags
}

# Make both Fargate capacity providers available on a cluster we own.
resource "aws_ecs_cluster_capacity_providers" "this" {
  count = var.create_cluster ? 1 : 0

  cluster_name       = aws_ecs_cluster.this[0].name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

# ---------------------------------------------------------------------------
# CloudWatch log group — KMS-encrypted when a key is supplied.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = local.log_kms_encrypted ? var.log_kms_key_arn : null

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# IAM — execution role (pull images, write logs, read secrets).
# ---------------------------------------------------------------------------

resource "aws_iam_role" "execution" {
  count = local.create_execution_role ? 1 : 0

  name               = "${var.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  count = local.create_execution_role ? 1 : 0

  role       = aws_iam_role.execution[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  count = (local.create_execution_role && local.has_secrets) ? 1 : 0

  name   = "${var.name}-ecs-execution-secrets"
  role   = aws_iam_role.execution[0].id
  policy = data.aws_iam_policy_document.execution_secrets[0].json
}

# ---------------------------------------------------------------------------
# IAM — task role (the app's own identity). Empty-policy by default; the
# caller attaches workload permissions via additional_task_role_policy_arns
# or out of band.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "task" {
  count = local.create_task_role ? 1 : 0

  name               = "${var.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "task_additional" {
  for_each = local.create_task_role ? toset(var.additional_task_role_policy_arns) : toset([])

  role       = aws_iam_role.task[0].name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------
# Service security group — ingress from the ALB (or other) SGs on the
# container port. Created unless the caller brings their own.
# ---------------------------------------------------------------------------

resource "aws_security_group" "service" {
  count = local.create_service_sg ? 1 : 0

  name        = "${var.name}-ecs-svc"
  description = "ECS service SG for ${var.name}. Ingress on container port from configured source SGs only."
  vpc_id      = var.vpc_id

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_sources" {
  for_each = local.create_service_sg ? toset(var.ingress_security_group_ids) : toset([])

  security_group_id            = aws_security_group.service[0].id
  description                  = "Container port from ${each.value}"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = local.create_service_sg ? 1 : 0

  security_group_id = aws_security_group.service[0].id
  description       = "All egress (image pulls, secrets, app traffic)."
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Task definition
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = local.execution_role_arn
  task_role_arn            = local.task_role_arn
  container_definitions    = local.container_definitions

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64" # Graviton — cheaper + greener; image must be arm64
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS service
# ---------------------------------------------------------------------------

resource "aws_ecs_service" "this" {
  name             = var.name
  cluster          = local.cluster_arn
  task_definition  = aws_ecs_task_definition.this.arn
  desired_count    = var.desired_count
  platform_version = var.platform_version

  capacity_provider_strategy {
    capacity_provider = local.capacity_provider
    weight            = 1
  }

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = local.service_security_groups
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = local.attach_to_alb ? [1] : []
    content {
      target_group_arn = var.alb_target_group_arn
      container_name   = local.container_name
      container_port   = var.container_port
    }
  }

  health_check_grace_period_seconds = local.attach_to_alb ? var.health_check_grace_period_seconds : null

  tags = local.common_tags

  lifecycle {
    # Ignore desired_count drift so an external autoscaler (or the
    # Application Auto Scaling policies below) owns the running count
    # without Terraform fighting it on every apply.
    ignore_changes = [desired_count]
  }

  depends_on = [aws_iam_role_policy_attachment.execution_managed]
}

# ---------------------------------------------------------------------------
# Application Auto Scaling — optional target tracking on CPU and/or memory.
# ---------------------------------------------------------------------------

resource "aws_appautoscaling_target" "this" {
  count = var.enable_autoscaling ? 1 : 0

  service_namespace  = "ecs"
  resource_id        = "service/${local.cluster_name_for_scaling}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.autoscaling_min_capacity
  max_capacity       = var.autoscaling_max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  count = local.cpu_scaling ? 1 : 0

  name               = "${var.name}-cpu-target-tracking"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.autoscaling_cpu_target
  }
}

resource "aws_appautoscaling_policy" "memory" {
  count = local.memory_scaling ? 1 : 0

  name               = "${var.name}-memory-target-tracking"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.autoscaling_memory_target
  }
}
