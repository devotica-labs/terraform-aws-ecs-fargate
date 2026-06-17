output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = module.ecs.cluster_arn
}

output "service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "task_definition_arn" {
  description = "Current task definition revision ARN."
  value       = module.ecs.task_definition_arn
}

output "execution_role_arn" {
  description = "Task execution role ARN."
  value       = module.ecs.execution_role_arn
}

output "task_role_arn" {
  description = "Task role ARN."
  value       = module.ecs.task_role_arn
}

output "security_group_id" {
  description = "Service security group ID."
  value       = module.ecs.security_group_id
}

output "log_group_name" {
  description = "CloudWatch log group."
  value       = module.ecs.log_group_name
}

output "autoscaling_target_resource_id" {
  description = "Application Auto Scaling target resource ID."
  value       = module.ecs.autoscaling_target_resource_id
}
