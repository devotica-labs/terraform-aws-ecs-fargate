output "service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "task_role_arn" {
  description = "Task role ARN — attach app permissions here."
  value       = module.ecs.task_role_arn
}

output "security_group_id" {
  description = "Service security group ID."
  value       = module.ecs.security_group_id
}
