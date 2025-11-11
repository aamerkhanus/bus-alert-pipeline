import json
import os
import time
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
cw = boto3.client("cloudwatch")

RAW_BUCKET = os.environ["RAW_BUCKET_NAME"]
TABLE_NAME = os.environ["DDB_TABLE_NAME"]
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "BusAlerts")

table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    # API Gateway sends the JSON body as a string in event["body"]
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "invalid json"})
        }

    # For now, just log and echo back
    logger.info(json.dumps({
        "message": "received bus event",
        "payload": body
    }))

    # Minimal happy-path response
    return {
        "statusCode": 200,
        "body": json.dumps({"status": "ok", "echo": body})
    }

