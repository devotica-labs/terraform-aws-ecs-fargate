# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/ecs-fargate/aws"
#   version = "~> 0.1"

module "ecs" {
  source = "../.."

  name = "devotica-prod-payments-api"

  vpc_id     = "vpc-00000000000000000"
  subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb", "subnet-ccccccccccccccccc"]

  # Ingress only from the ALB's security group (terraform-aws-alb output).
  ingress_security_group_ids = ["sg-0albalbalbalbalb0"]

  # Container
  container_image = "111122223333.dkr.ecr.ap-south-1.amazonaws.com/payments-api:1.4.2"
  container_name  = "payments-api"
  container_port  = 8080
  cpu             = 1024
  memory          = 2048

  environment = {
    APP_ENV   = "production"
    LOG_LEVEL = "info"
  }

  # Secret env vars pulled from Secrets Manager — the execution role is
  # granted read + KMS decrypt automatically.
  secrets = {
    DATABASE_URL    = "arn:aws:secretsmanager:ap-south-1:111122223333:secret:payments/db-url-AbCdEf"
    JWT_SIGNING_KEY = "arn:aws:secretsmanager:ap-south-1:111122223333:secret:payments/jwt-AbCdEf"
  }

  readonly_root_filesystem = true

  # Task role gets workload permissions (e.g. read the data bucket).
  additional_task_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
  ]

  # Logs encrypted with the workload KMS key (terraform-aws-kms output).
  log_kms_key_arn    = "arn:aws:kms:ap-south-1:111122223333:key/00000000-0000-0000-0000-000000000000"
  log_retention_days = 90

  # Service
  desired_count          = 3
  enable_execute_command = false

  # Register with the ALB target group (terraform-aws-alb output).
  alb_target_group_arn              = "arn:aws:elasticloadbalancing:ap-south-1:111122223333:targetgroup/devotica-prod-edge-api/0123456789abcdef"
  health_check_grace_period_seconds = 90

  # Target-tracking autoscaling on CPU + memory.
  enable_autoscaling        = true
  autoscaling_min_capacity  = 3
  autoscaling_max_capacity  = 20
  autoscaling_cpu_target    = 65
  autoscaling_memory_target = 75

  tags = {
    Environment = "production"
    Project     = "payments"
    Owner       = "payments-team@devotica.com"
    CostCenter  = "PAYMENTS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-ecs-fargate"
  }
}
