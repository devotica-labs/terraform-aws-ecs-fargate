data "aws_region" "current" {}
data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# Trust policy for both ECS roles — assumed by the ECS tasks service.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_assume" {
  count = (local.create_execution_role || local.create_task_role) ? 1 : 0

  statement {
    sid     = "ECSTasksAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# Execution-role extras — read the configured secrets and (when encrypted)
# decrypt them with the workload KMS key. Only rendered when we create the
# execution role AND there are secrets to read.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "execution_secrets" {
  count = (local.create_execution_role && local.has_secrets) ? 1 : 0

  statement {
    sid       = "ReadSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "ssm:GetParameters"]
    resources = values(var.secrets)
  }

  dynamic "statement" {
    for_each = local.log_kms_encrypted ? [1] : []
    content {
      sid       = "DecryptSecrets"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [var.log_kms_key_arn]
    }
  }
}
