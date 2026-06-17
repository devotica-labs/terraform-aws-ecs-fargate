# ---------------------------------------------------------------------------
# Core identity
# ---------------------------------------------------------------------------

variable "name" {
  description = "Logical name for the service. Used as the prefix for the cluster (when created), task family, service, log group, IAM roles, and security group."
  type        = string
  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 60 && can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]*$", var.name))
    error_message = "name must be 1–60 chars, alphanumeric plus _ and -, starting alphanumeric."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC the service runs in. Used for the auto-created service security group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs the Fargate tasks attach to. Should be PRIVATE subnets — tasks reach the internet via NAT, and inbound traffic arrives via the ALB. Must span at least two AZs for HA."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "Provide at least one subnet (two+ across AZs for HA)."
  }
}

variable "assign_public_ip" {
  description = "Assign a public IP to each task ENI. Default false — Fargate tasks belong in private subnets behind the ALB. Only set true for tasks in public subnets without a NAT gateway (not recommended for fintech)."
  type        = bool
  default     = false
}

variable "ingress_security_group_ids" {
  description = "Security group IDs allowed to reach the tasks on container_port — typically the ALB's security group. Used by the auto-created service SG. Ignored when service_security_group_ids is set."
  type        = list(string)
  default     = []
}

variable "service_security_group_ids" {
  description = "Bring-your-own security group IDs for the service. When set, the module does NOT create a security group and ignores ingress_security_group_ids."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Cluster — create one, or bring your own.
# ---------------------------------------------------------------------------

variable "create_cluster" {
  description = "Create a new ECS cluster. Set false to attach the service to an existing cluster supplied via cluster_arn."
  type        = bool
  default     = true
}

variable "cluster_arn" {
  description = "ARN of an existing ECS cluster to deploy into. Required when create_cluster = false; ignored otherwise."
  type        = string
  default     = ""
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights on the created cluster (metrics + per-task observability). Ignored when create_cluster = false."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Task definition — single container in v0.1 (sidecars deferred).
# ---------------------------------------------------------------------------

variable "container_image" {
  description = "Container image URI (e.g. <account>.dkr.ecr.<region>.amazonaws.com/app:tag or a public image)."
  type        = string
}

variable "container_name" {
  description = "Name of the container in the task definition. Defaults to var.name when empty."
  type        = string
  default     = ""
}

variable "container_port" {
  description = "Port the container listens on. Also the target-group / SG ingress port."
  type        = number
  default     = 8080
  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be 1–65535."
  }
}

variable "cpu" {
  description = "Task-level CPU units (Fargate valid combos: 256, 512, 1024, 2048, 4096, 8192, 16384)."
  type        = number
  default     = 512
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu)
    error_message = "cpu must be a valid Fargate value: 256, 512, 1024, 2048, 4096, 8192, 16384."
  }
}

variable "memory" {
  description = "Task-level memory (MiB). Must be a valid pairing with cpu — see AWS Fargate task size table."
  type        = number
  default     = 1024
  validation {
    condition     = var.memory >= 512 && var.memory <= 122880
    error_message = "memory must be between 512 and 122880 MiB."
  }
}

variable "environment" {
  description = "Plain (non-secret) environment variables for the container, as a name → value map."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secret environment variables, as name → ARN map. ARN points at a Secrets Manager secret or SSM SecureString parameter. Injected via the ECS `secrets` block; the execution role is granted read on these."
  type        = map(string)
  default     = {}
}

variable "command" {
  description = "Override the container's CMD. Empty list uses the image default."
  type        = list(string)
  default     = []
}

variable "readonly_root_filesystem" {
  description = "Mount the container root filesystem read-only (defence in depth; satisfies CKV_AWS_336). Default true. Set false for apps that must write to the root fs (prefer a writable volume/tmpfs instead)."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# IAM — execution + task roles. Created inline by default; override with ARNs.
# ---------------------------------------------------------------------------

variable "task_execution_role_arn" {
  description = "ARN of an existing task EXECUTION role (pulls images, writes logs, reads secrets). Empty (default) makes the module create one with AmazonECSTaskExecutionRolePolicy + read on var.secrets + KMS decrypt."
  type        = string
  default     = ""
}

variable "task_role_arn" {
  description = "ARN of an existing TASK role (the identity the app code assumes — e.g. to call S3/RDS IAM-auth). Empty (default) makes the module create an empty-policy role you can attach policies to out-of-band, or via additional_task_role_policy_arns."
  type        = string
  default     = ""
}

variable "additional_task_role_policy_arns" {
  description = "Managed-policy ARNs to attach to the created task role. Ignored when task_role_arn is supplied."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the task's log group."
  type        = number
  default     = 30
  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days must be an AWS-supported value."
  }
}

variable "log_kms_key_arn" {
  description = "KMS key ARN to encrypt the CloudWatch log group (typically the workload key from terraform-aws-kms). Empty uses AWS-owned default encryption. The key policy must allow the CloudWatch Logs service in this region."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

variable "desired_count" {
  description = "Number of task copies to run. 2+ for HA across AZs."
  type        = number
  default     = 2
  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count must be >= 0."
  }
}

variable "platform_version" {
  description = "Fargate platform version. LATEST tracks the newest, which AWS keeps backward-compatible."
  type        = string
  default     = "LATEST"
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower bound (% of desired_count) that must stay RUNNING during a deployment."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Upper bound (% of desired_count) allowed to run during a deployment (rolling headroom)."
  type        = number
  default     = 200
}

variable "enable_execute_command" {
  description = "Enable ECS Exec (interactive shell into running tasks). Default false — it's a powerful debugging backdoor; enable deliberately and audit via CloudTrail when you do."
  type        = bool
  default     = false
}

variable "use_fargate_spot" {
  description = "Run tasks on FARGATE_SPOT (cheaper, interruptible) instead of on-demand FARGATE. Use only for fault-tolerant / non-critical workloads (e.g. sandbox)."
  type        = bool
  default     = false
}

variable "health_check_grace_period_seconds" {
  description = "Grace period before the ECS service starts honoring ALB health checks on new tasks. Only applies when alb_target_group_arn is set. Give slow-booting apps enough time."
  type        = number
  default     = 60
}

# ---------------------------------------------------------------------------
# ALB attachment — optional. Pairs with terraform-aws-alb target groups.
# ---------------------------------------------------------------------------

variable "alb_target_group_arn" {
  description = "ARN of an ALB target group to register the service with. Empty (default) runs the service without a load balancer (e.g. a worker/queue consumer)."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Autoscaling — optional target tracking.
# ---------------------------------------------------------------------------

variable "enable_autoscaling" {
  description = "Enable Application Auto Scaling (target tracking on CPU and/or memory) for the service."
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "Minimum task count when autoscaling is enabled."
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum task count when autoscaling is enabled."
  type        = number
  default     = 10
}

variable "autoscaling_cpu_target" {
  description = "Target average CPU utilisation (%) for the CPU target-tracking policy. 0 disables the CPU policy."
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target average memory utilisation (%) for the memory target-tracking policy. 0 disables the memory policy."
  type        = number
  default     = 0
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags merged onto every taggable resource."
  type        = map(string)
  default     = {}
}
