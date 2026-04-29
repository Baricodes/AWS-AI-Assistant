#!/usr/bin/env bash
set -euo pipefail

FUNCTION_NAME="${FUNCTION_NAME:-aws-ai-assistant-whitepaper-scheduler}"
REGION="us-east-1"
OUTPUT_PATH="${1:-/tmp/whitepaper-scheduler-response.json}"

aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" \
  "$OUTPUT_PATH"

echo "Lambda response written to $OUTPUT_PATH"
