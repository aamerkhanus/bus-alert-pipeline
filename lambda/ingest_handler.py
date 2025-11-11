import json
import os
import logging
from datetime import datetime, timezone
import re

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")

RAW_BUCKET_NAME = os.environ["RAW_BUCKET_NAME"]
DDB_TABLE_NAME = os.environ["DDB_TABLE_NAME"]
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "BusAlerts")

table = dynamodb.Table(DDB_TABLE_NAME)

HIGH = {"Mechanical Problem", "Flat Tire", "Won't Start", "Accident"}
MEDIUM = {"Heavy Traffic", "Weather Conditions"}
LOW = {"Delayed by School", "Other", "Problem Run"}


def parse_minutes(delay_str):
    """
    "30 Min" -> 30
    "25-35 Mins" -> 30
    "1 Hour" -> 60
    "1-2 Hours" -> 90
    Returns None if unparseable.
    """
    if not delay_str:
        return None

    s = str(delay_str).strip().lower()

    # e.g., "25-35 mins", "1-2 hours"
    m = re.match(r"^\s*(\d+)\s*-\s*(\d+)\s*(min|mins|minute|minutes|hour|hours)\s*$", s)
    if m:
        a, b, unit = int(m.group(1)), int(m.group(2)), m.group(3)
        avg = (a + b) // 2
        return avg if unit.startswith("min") else avg * 60

    # e.g., "30 min", "1 hour"
    m = re.match(r"^\s*(\d+)\s*(min|mins|minute|minutes|hour|hours)\s*$", s)
    if m:
        val, unit = int(m.group(1)), m.group(2)
        return val if unit.startswith("min") else val * 60

    # plain number
    m = re.match(r"^\s*(\d+)\s*$", s)
    if m:
        return int(m.group(1))

    return None


def derive_priority(reason):
    if not reason:
        return "low"
    r = str(reason).strip()
    if r in HIGH:
        return "high"
    if r in MEDIUM:
        return "medium"
    if r in LOW:
        return "low"
    return "low"  # default per spec


def normalize_timestamp(occurred_on):
    """
    Normalize to ISO8601 UTC like 'YYYY-MM-DDTHH:MM:SSZ'.
    """
    try:
        dt = datetime.fromisoformat(str(occurred_on).replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except Exception:
        return str(occurred_on)


def put_high_priority_metric():
    cloudwatch.put_metric_data(
        Namespace=METRIC_NAMESPACE,
        MetricData=[{"MetricName": "HighPriorityAlerts", "Value": 1, "Unit": "Count"}],
    )


def lambda_handler(event, context):
    # A) Parse input JSON from API Gateway
    try:
        if isinstance(event, dict) and "body" in event and isinstance(event["body"], str):
            payload = json.loads(event["body"])
        elif isinstance(event, dict):
            # allow direct test invoke
            payload = event
        else:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "invalid event shape"}),
            }
    except Exception as e:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Invalid JSON body", "detail": str(e)}),
        }

    # B) Validate required fields
    required = ["Busbreakdown_ID", "Route_Number", "Reason", "Occurred_On"]
    missing = [k for k in required if k not in payload or payload[k] in (None, "")]
    if missing:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Missing required fields", "missing": missing}),
        }

    Busbreakdown_ID = payload["Busbreakdown_ID"]
    Route_Number = str(payload["Route_Number"])
    Reason = str(payload["Reason"])
    Occurred_On = str(payload["Occurred_On"])

    # C) Priority
    alert_priority = derive_priority(Reason)

    # D) Delay minutes
    average_delay_minutes = parse_minutes(payload.get("How_Long_Delayed", ""))

    # Normalize timestamp
    occurred_on_norm = normalize_timestamp(Occurred_On)

    # E) Write raw payload to S3
    s3_key = f"raw/{occurred_on_norm}_{Busbreakdown_ID}.json"
    s3.put_object(
        Bucket=RAW_BUCKET_NAME,
        Key=s3_key,
        Body=json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        ContentType="application/json",
    )

    # F) Write transformed record to DynamoDB
    item = {
        "Route_Number": Route_Number,
        "Occurred_On": occurred_on_norm,
        "Busbreakdown_ID": int(Busbreakdown_ID),
        "Reason": Reason,
        "alert_priority": alert_priority,
        "average_delay_minutes": average_delay_minutes if average_delay_minutes is not None else -1,
        "s3_key": s3_key,
        "ingested_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    table.put_item(Item=item)

    # G) Emit custom metric for high alerts
    if alert_priority == "high":
        put_high_priority_metric()

    # H) Structured log
    logger.info(
        json.dumps(
            {
                "event": "bus_event_processed",
                "Busbreakdown_ID": Busbreakdown_ID,
                "Route_Number": Route_Number,
                "alert_priority": alert_priority,
            }
        )
    )

    # I) Return 200 JSON
    resp = {
        "status": "ok",
        "alert_priority": alert_priority,
        "average_delay_minutes": average_delay_minutes,
    }
    return {"statusCode": 200, "headers": {"Content-Type": "application/json"}, "body": json.dumps(resp)}
