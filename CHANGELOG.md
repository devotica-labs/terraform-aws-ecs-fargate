# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut automatically by `release-please` on merge to `main`,
driven by Conventional Commit prefixes (`feat:` → minor, `fix:`/`docs:`/`chore:` → patch,
`feat!:` or `BREAKING CHANGE:` footer → major).

## [Unreleased]

### Added
- Initial module scaffold.
- ECS cluster (created by default; bring-your-own via `cluster_arn`) with
  Container Insights and both FARGATE + FARGATE_SPOT capacity providers.
- Single-container Fargate task definition (awsvpc, ARM64/Graviton,
  read-only root filesystem by default), with plain `environment` and
  `secrets` (Secrets Manager / SSM) injection.
- Inline task execution + task IAM roles (override with ARNs). Execution
  role gets `AmazonECSTaskExecutionRolePolicy` + read on the configured
  secrets + KMS decrypt; task role takes `additional_task_role_policy_arns`.
- ECS service: configurable desired count, rolling-deploy bounds,
  on-demand or FARGATE_SPOT, optional ECS Exec (off by default), optional
  ALB target-group attachment with health-check grace period.
- Auto-created service security group (ingress from configured source SGs
  on the container port; all egress) — or bring your own.
- KMS-encryptable CloudWatch log group with configurable retention.
- Optional Application Auto Scaling: target tracking on CPU and/or memory.
- `examples/basic` (public nginx image, ALB-less) and `examples/complete`
  (ECR image, secrets, ALB attach, KMS logs, CPU+memory autoscaling).
- `tests/unit.tftest.hcl` (mock-provider, plan-only) +
  `tests/contract.tftest.hcl` + `tests/integration.tftest.hcl`.

### Deferred to later versions
- Sidecar / multi-container task definitions.
- Cloud Map service discovery.
- EFS volume mounts.
- Blue/green deployments via CodeDeploy.
