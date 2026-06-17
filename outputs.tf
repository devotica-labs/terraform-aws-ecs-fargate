output "cluster_arn" {
  description = "ARN of the ECS cluster the service runs in (created or caller-supplied)."
  value       = local.cluster_arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = local.cluster_name_for_scaling
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "service_id" {
  description = "ID (ARN) of the ECS service."
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ARN of the current task definition revision."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Task definition family name."
  value       = aws_ecs_task_definition.this.family
}

output "execution_role_arn" {
  description = "ARN of the task execution role (created or caller-supplied)."
  value       = local.execution_role_arn
}

output "task_role_arn" {
  description = "ARN of the task role — attach app/workload permissions here (created or caller-supplied)."
  value       = local.task_role_arn
}

output "task_role_name" {
  description = "Name of the created task role (empty when a task_role_arn was supplied). Use to attach inline/managed policies out of band."
  value       = local.create_task_role ? aws_iam_role.task[0].name : ""
}

output "security_group_id" {
  description = "ID of the auto-created service security group. Empty string when service_security_group_ids was supplied. App tiers (e.g. RDS) should allow ingress from this SG."
  value       = local.create_service_sg ? aws_security_group.service[0].id : ""
}

output "log_group_name" {
  description = "CloudWatch log group the task logs to."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group."
  value       = aws_cloudwatch_log_group.this.arn
}

output "autoscaling_target_resource_id" {
  description = "Application Auto Scaling target resource ID (empty when autoscaling disabled)."
  value       = var.enable_autoscaling ? aws_appautoscaling_target.this[0].resource_id : ""
}
