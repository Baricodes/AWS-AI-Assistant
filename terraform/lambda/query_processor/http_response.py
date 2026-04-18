"""API Gateway HTTP API v2 Lambda response helpers and CORS headers."""

import json

from query_processor import config

CORS_HEADERS = {
    "Access-Control-Allow-Origin": config.CORS_ALLOW_ORIGIN,
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
}


def response(status, body_obj=None, headers=None):
    base_headers = {"Content-Type": "application/json", **CORS_HEADERS}
    if headers:
        base_headers.update(headers)
    return {
        "statusCode": status,
        "headers": base_headers,
        "body": json.dumps(body_obj) if body_obj is not None else "",
    }
