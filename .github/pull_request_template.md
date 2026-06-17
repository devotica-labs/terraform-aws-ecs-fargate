## Summary
<!-- What does this PR do? -->

## Type of change
- [ ] `feat:` new variable / output / feature (minor bump)
- [ ] `fix:` bug fix (patch bump)
- [ ] `feat!:` breaking change (major bump)
- [ ] `docs:` documentation only
- [ ] `chore:` tooling / CI / deps

## Checklist
- [ ] `terraform fmt` clean
- [ ] `terraform validate` passes
- [ ] Unit + contract tests pass (`terraform test`)
- [ ] `terraform-docs` output up to date
- [ ] No secrets committed (`gitleaks` clean)
- [ ] PR title follows Conventional Commits

## Breaking changes
<!-- List any removed/renamed variables/outputs.

     Any change to a security-relevant default (assign_public_ip,
     enable_execute_command, readonly_root_filesystem, the service SG ingress
     model) is a consumer-facing breaking change — flag it here. -->
