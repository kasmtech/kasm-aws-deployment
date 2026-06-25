"""Aurora Global Database cross-region failover automation.

Triggered by EventBridge from a CloudWatch alarm on the primary cluster.
Re-verifies that the primary is truly unreachable (alarm flapping protection),
picks a healthy secondary cluster as the promotion target, and calls
failover-global-cluster.

Environment variables:
  GLOBAL_CLUSTER_ID  - Aurora global cluster identifier (required)
  SNS_TOPIC_ARN      - SNS topic for status notifications (required)
  ALLOW_DATA_LOSS    - "true" | "false" - whether unplanned failover is permitted
  LOG_LEVEL          - Python logging level (default INFO)
"""

import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

GLOBAL_CLUSTER_ID = os.environ["GLOBAL_CLUSTER_ID"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
ALLOW_DATA_LOSS = os.environ.get("ALLOW_DATA_LOSS", "true").lower() == "true"

rds = boto3.client("rds")
sns = boto3.client("sns")


def notify(subject, body):
    """Publish a status message to SNS. Best-effort; never raises."""
    try:
        sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=subject[:100], Message=body)
    except ClientError:
        logger.exception("SNS publish failed for subject %r", subject)


def describe_global_cluster():
    response = rds.describe_global_clusters(GlobalClusterIdentifier=GLOBAL_CLUSTER_ID)
    clusters = response.get("GlobalClusters", [])
    if not clusters:
        raise RuntimeError("global cluster {} not found".format(GLOBAL_CLUSTER_ID))
    return clusters[0]


def parse_cluster_arn(arn):
    """Return (region, cluster_id) for an RDS cluster ARN.

    ARN format: arn:aws:rds:<region>:<acct>:cluster:<cluster-id>
    """
    parts = arn.split(":")
    if len(parts) < 7:
        raise ValueError("malformed cluster ARN: {}".format(arn))
    return parts[3], parts[6]


def get_cluster_status(arn):
    """Return the regional cluster's status string, or None if it can't be reached.

    Returning None is treated as 'unhealthy' by callers, which is the safe
    interpretation when the primary region is the unreachable one.
    """
    try:
        region, cluster_id = parse_cluster_arn(arn)
        regional_rds = boto3.client("rds", region_name=region)
        response = regional_rds.describe_db_clusters(DBClusterIdentifier=cluster_id)
        clusters = response.get("DBClusters", [])
        if not clusters:
            return None
        return clusters[0].get("Status")
    except (ClientError, ValueError):
        logger.warning("describe_db_clusters failed for %s", arn, exc_info=True)
        return None


def pick_promotion_target(secondaries):
    """Return the first secondary whose regional cluster reports 'available', or None."""
    for member in secondaries:
        status = get_cluster_status(member["DBClusterArn"])
        if status == "available":
            return member
    return None


def handler(event, _context):
    logger.info("Failover handler invoked: %s", json.dumps(event, default=str))

    try:
        global_cluster = describe_global_cluster()
    except Exception as exc:  # noqa: BLE001 — broad catch is intentional at the top level
        message = "describe_global_clusters failed: {}".format(exc)
        logger.exception(message)
        notify("Aurora failover FAILED ({})".format(GLOBAL_CLUSTER_ID), message)
        return {"status": "error", "reason": message}

    members = global_cluster.get("GlobalClusterMembers", [])
    writer = next((m for m in members if m.get("IsWriter")), None)
    secondaries = [m for m in members if not m.get("IsWriter")]

    if writer is None:
        message = "no writer found in global cluster — may be mid-failover or misconfigured"
        logger.info(message)
        notify("Aurora failover SKIPPED ({})".format(GLOBAL_CLUSTER_ID), message)
        return {"status": "skipped", "reason": message}

    if not secondaries:
        message = "no secondary clusters available to promote"
        logger.warning(message)
        notify("Aurora failover SKIPPED ({})".format(GLOBAL_CLUSTER_ID), message)
        return {"status": "skipped", "reason": message}

    ## Re-verify the writer is unhealthy. Alarms can flap; we don't want to fail
    ## over for a transient blip.
    writer_status = get_cluster_status(writer["DBClusterArn"])
    if writer_status == "available":
        message = "writer reports 'available' on re-check — skipping failover (alarm likely flapped)"
        logger.info(message)
        notify("Aurora failover SKIPPED ({})".format(GLOBAL_CLUSTER_ID), message)
        return {"status": "skipped", "reason": message}

    target = pick_promotion_target(secondaries)
    if target is None:
        message = "no healthy secondary cluster found to promote"
        logger.error(message)
        notify("Aurora failover FAILED ({})".format(GLOBAL_CLUSTER_ID), message)
        return {"status": "error", "reason": message}

    target_arn = target["DBClusterArn"]
    target_region, _ = parse_cluster_arn(target_arn)

    try:
        rds.failover_global_cluster(
            GlobalClusterIdentifier=GLOBAL_CLUSTER_ID,
            TargetDbClusterIdentifier=target_arn,
            AllowDataLoss=ALLOW_DATA_LOSS,
        )
    except ClientError as exc:
        message = "failover_global_cluster call failed: {}".format(exc)
        logger.exception(message)
        notify("Aurora failover FAILED ({})".format(GLOBAL_CLUSTER_ID), message)
        return {"status": "error", "reason": message}

    success = (
        "Aurora failover INITIATED. New primary: {} (region {}). "
        "AllowDataLoss={}.".format(target_arn, target_region, ALLOW_DATA_LOSS)
    )
    logger.info(success)
    notify("Aurora failover INITIATED ({})".format(GLOBAL_CLUSTER_ID), success)
    return {
        "status": "initiated",
        "new_primary_arn": target_arn,
        "new_primary_region": target_region,
    }
