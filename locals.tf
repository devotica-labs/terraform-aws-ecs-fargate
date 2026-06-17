locals {
  common_tags = merge(
    { ManagedBy = "terraform", Module = "terraform-aws-ecs-fargate" },
    var.tags
  )

  container_name = var.container_name != "" ? var.container_name : var.name
  log_group_name = "/ecs/${var.name}"

  # Cluster the service runs in: created here, or caller-supplied.
  cluster_arn = var.create_cluster ? aws_ecs_cluster.this[0].arn : var.cluster_arn

  # Application Auto Scaling resource IDs use the cluster NAME, not its ARN.
  # For a created cluster that's var.name; for a BYO cluster, parse the ARN
  # tail (arn:aws:ecs:...:cluster/<name>).
  cluster_name_for_scaling = var.create_cluster ? var.name : element(split("/", var.cluster_arn), length(split("/", var.cluster_arn)) - 1)

  # IAM roles: created here, or caller-supplied ARNs.
  create_execution_role = var.task_execution_role_arn == ""
  create_task_role      = var.task_role_arn == ""
  execution_role_arn    = local.create_execution_role ? aws_iam_role.execution[0].arn : var.task_execution_role_arn
  task_role_arn         = local.create_task_role ? aws_iam_role.task[0].arn : var.task_role_arn

  # Service SG: created here (ingress from ingress_security_group_ids), or BYO.
  create_service_sg       = length(var.service_security_group_ids) == 0
  service_security_groups = local.create_service_sg ? [aws_security_group.service[0].id] : var.service_security_group_ids

  has_secrets       = length(var.secrets) > 0
  attach_to_alb     = var.alb_target_group_arn != ""
  log_kms_encrypted = var.log_kms_key_arn != ""

  # Target-tracking policies only created when their target > 0.
  cpu_scaling    = var.enable_autoscaling && var.autoscaling_cpu_target > 0
  memory_scaling = var.enable_autoscaling && var.autoscaling_memory_target > 0

  # Capacity provider strategy: on-demand FARGATE or interruptible FARGATE_SPOT.
  capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"

  # Container definition rendered to JSON for the task definition.
  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = var.container_image
      essential = true
      cpu       = var.cpu
      memory    = var.memory

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      command = length(var.command) > 0 ? var.command : null

      readonlyRootFilesystem = var.readonly_root_filesystem

      environment = [
        for k, v in var.environment : { name = k, value = v }
      ]

      secrets = [
        for k, arn in var.secrets : { name = k, valueFrom = arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group_name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}
