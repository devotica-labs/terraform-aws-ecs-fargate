#!/usr/bin/env python3
"""Render an ECS Fargate architecture diagram from a Terraform plan JSON.

Centres the ECS service inside its cluster, with edges to:
  - the task definition (cpu/memory, container image)
  - execution + task IAM roles
  - the CloudWatch log group (and KMS when encrypted)
  - the ALB target group (when attached)
  - the service security group
  - autoscaling target (when enabled)

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import ECS, Fargate
from diagrams.aws.management import Cloudwatch
from diagrams.aws.network import ELB
from diagrams.aws.security import IAMRole, KMS


def load_resources(plan_path: Path) -> list[dict]:
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def values(r: dict) -> dict:
    return r.get("values", {}) or {}


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)
    by_type: dict[str, list[dict]] = {}
    for r in resources:
        by_type.setdefault(r["type"], []).append(r)

    svcs = by_type.get("aws_ecs_service", [])
    if not svcs:
        raise SystemExit("No aws_ecs_service found in plan — nothing to render.")

    svc_v = values(svcs[0])
    svc_name = svc_v.get("name") or "service"
    desired = svc_v.get("desired_count")
    exec_cmd = bool(svc_v.get("enable_execute_command"))

    tds = by_type.get("aws_ecs_task_definition", [])
    td_v = values(tds[0]) if tds else {}
    cpu = td_v.get("cpu", "?")
    memory = td_v.get("memory", "?")

    has_cluster = bool(by_type.get("aws_ecs_cluster"))
    exec_roles = [r for r in by_type.get("aws_iam_role", []) if ".execution" in r["address"]]
    task_roles = [r for r in by_type.get("aws_iam_role", []) if ".task" in r["address"]]
    has_sg = bool(by_type.get("aws_security_group"))
    has_log = bool(by_type.get("aws_cloudwatch_log_group"))
    log_v = values(by_type.get("aws_cloudwatch_log_group", [{}])[0]) if has_log else {}
    log_kms = bool(log_v.get("kms_key_id"))
    attach_alb = bool(svc_v.get("load_balancer"))
    has_autoscaling = bool(by_type.get("aws_appautoscaling_target"))

    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "1.0",
        "nodesep": "0.5",
        "pad": "0.5",
    }

    badges = [f"desired={desired}"]
    badges.append("FARGATE_SPOT" if (svc_v.get("capacity_provider_strategy") and
                  any(c.get("capacity_provider") == "FARGATE_SPOT" for c in svc_v["capacity_provider_strategy"])) else "FARGATE")
    if exec_cmd:
        badges.append("ECS Exec ON")
    if has_autoscaling:
        badges.append("autoscaling")

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)
    with Diagram(
        f"terraform-aws-ecs-fargate — {svc_name} ({cpu}cpu/{memory}mem) · {' · '.join(badges)}",
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        outformat="png",
        graph_attr=graph_attr,
    ):
        if attach_alb:
            alb_tg = ELB("ALB target group")
        else:
            alb_tg = None

        cluster_label = f"ECS cluster — {svc_name}" if has_cluster else "ECS cluster (external)"
        with Cluster(cluster_label):
            task = Fargate(f"task\n{cpu}cpu / {memory}mem")
            svc_node = ECS(f"service\n{svc_name}")
            svc_node >> Edge(label="runs") >> task

            if attach_alb and alb_tg is not None:
                alb_tg >> Edge(label="traffic") >> svc_node

            # IAM roles
            with Cluster("IAM"):
                for _ in exec_roles:
                    IAMRole("execution role") >> Edge(style="dashed", label="pull+logs+secrets") >> task
                for _ in task_roles:
                    IAMRole("task role") >> Edge(style="dashed", label="app identity") >> task

            # Logs
            if has_log:
                log_node = Cloudwatch("log group")
                task >> Edge(label="logs") >> log_node
                if log_kms:
                    KMS("KMS") >> Edge(style="dashed", label="encrypts") >> log_node


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: render-architecture.py <plan.json> <output-path-without-ext>\n")
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
