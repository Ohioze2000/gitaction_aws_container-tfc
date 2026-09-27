import json
import os
import urllib.request
from datetime import datetime, timezone

import boto3

ecs = boto3.client("ecs")
elbv2 = boto3.client("elbv2")

SLACK_WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]
ECS_CLUSTER = os.environ["ECS_CLUSTER_NAME"]
ECS_SERVICE = os.environ["ECS_SERVICE_NAME"]
ENV_PREFIX = os.environ["ENV_PREFIX"]
TARGET_GROUP_ARN = os.environ["TARGET_GROUP_ARN"]


def parse_sns_message(record):
    message = record["Sns"]["Message"]
    try:
        return json.loads(message)
    except json.JSONDecodeError:
        return {
            "AlarmName": "Unknown",
            "NewStateValue": "UNKNOWN",
            "NewStateReason": message,
        }


def get_unhealthy_targets():
    response = elbv2.describe_target_health(TargetGroupArn=TARGET_GROUP_ARN)
    return [
        {
            "id": item.get("Target", {}).get("Id", "unknown"),
            "port": item.get("Target", {}).get("Port", "unknown"),
            "state": item.get("TargetHealth", {}).get("State", "unknown"),
            "reason": item.get("TargetHealth", {}).get("Reason", ""),
            "description": item.get("TargetHealth", {}).get("Description", ""),
        }
        for item in response.get("TargetHealthDescriptions", [])
        if item.get("TargetHealth", {}).get("State") != "healthy"
    ]


def get_ecs_runtime():
    response = ecs.describe_services(cluster=ECS_CLUSTER, services=[ECS_SERVICE])
    service = response.get("services", [{}])[0]
    return {
        "desired": service.get("desiredCount", 0),
        "running": service.get("runningCount", 0),
        "pending": service.get("pendingCount", 0),
        "deployments": len(service.get("deployments", [])),
    }


def build_message(alarm):
    state = alarm.get("NewStateValue", "UNKNOWN")
    name = alarm.get("AlarmName", "Unknown alarm")
    reason = alarm.get("NewStateReason", "No reason supplied")
    timestamp = alarm.get("StateChangeTime") or datetime.now(timezone.utc).isoformat()
    trigger = alarm.get("Trigger", {})

    try:
        runtime = get_ecs_runtime()
    except Exception as exc:
        runtime = {
            "desired": "unknown",
            "running": "unknown",
            "pending": "unknown",
            "deployments": f"lookup failed: {exc}",
        }

    unhealthy = []
    if trigger.get("MetricName") == "UnHealthyHostCount":
        try:
            unhealthy = get_unhealthy_targets()
        except Exception as exc:
            unhealthy = [{
                "id": "lookup-failed",
                "port": "-",
                "state": "unknown",
                "reason": str(exc),
                "description": "",
            }]

    signal = trigger.get("MetricName", "CloudWatch alarm")
    lines = [
        f"*{ENV_PREFIX} Runtime Alert*",
        f"*Signal:* `{signal}`",
        f"*Alarm:* `{name}`",
        f"*State:* `{state}`",
        f"*Time:* `{timestamp}`",
        f"*Reason:* {reason}",
        f"*ECS:* desired={runtime['desired']} running={runtime['running']} pending={runtime['pending']}",
    ]

    if unhealthy:
        lines.append("*Unhealthy ALB targets:*")
        for target in unhealthy:
            lines.append(
                f"• `{target['id']}:{target['port']}` — {target['state']} "
                f"({target['reason'] or target['description'] or 'no reason supplied'})"
            )

    return "\n".join(lines)


def send_slack(text):
    payload = json.dumps({"text": text}).encode("utf-8")
    request = urllib.request.Request(
        SLACK_WEBHOOK_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"Slack webhook returned HTTP {response.status}")


def lambda_handler(event, context):
    processed = 0
    for record in event.get("Records", []):
        alarm = parse_sns_message(record)
        send_slack(build_message(alarm))
        processed += 1

    return {"statusCode": 200, "processed": processed}
