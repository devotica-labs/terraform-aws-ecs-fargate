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

  name = "my-app"

  vpc_id     = "vpc-00000000000000000"
  subnet_ids = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]

  # Allow inbound on the container port from the ALB's security group.
  ingress_security_group_ids = ["sg-00000000000000000"]

  container_image = "public.ecr.aws/nginx/nginx:1.27-alpine"
  container_port  = 80

  # Defaults already cover the fintech baseline: private networking,
  # assign_public_ip = false, container insights on, read-only root fs,
  # ECS Exec off, 2 desired tasks, ARM64/Graviton.

  tags = {
    Environment = "example"
    Project     = "terraform-aws-ecs-fargate"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM-OSS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-ecs-fargate"
  }
}
