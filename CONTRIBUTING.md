# Contributing

## Setup

```bash
brew install terraform tflint tfsec gitleaks pre-commit terraform-docs
pre-commit install
```

## Running tests locally

```bash
terraform init -backend=false
terraform test -filter=tests/unit.tftest.hcl
terraform test -filter=tests/contract.tftest.hcl
```

The integration test needs real AWS creds + a pre-existing VPC, private subnets, and a source security group. Run via `workflow_dispatch` on `integration.yml`, or locally:

```bash
terraform test -filter=tests/integration.tftest.hcl \
  -var=vpc_id=vpc-... \
  -var='subnet_ids=["subnet-a","subnet-b"]' \
  -var='ingress_security_group_ids=["sg-..."]'
```

## Commit message format

We use [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Semver bump |
|---|---|
| `feat:` | minor |
| `fix:`, `docs:`, `chore:` | patch |
| `feat!:` or `BREAKING CHANGE:` footer | major |

## Branch protection

`main` requires all CI checks green + one non-author review.
No direct pushes.
