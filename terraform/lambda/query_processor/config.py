"""Environment-driven settings for the query processor."""

import os

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "us-east-1")
OS_REGION = os.environ.get("OPENSEARCH_REGION", "us-east-1")
EMBED_MODEL_ID = os.environ.get(
    "EMBED_MODEL_ID",
    "amazon.titan-embed-text-v2:0",
)
GEN_MODEL_ID = os.environ.get(
    "GEN_MODEL_ID",
    "anthropic.claude-sonnet-4-20250514-v1:0",
)
GEN_INFERENCE_PROFILE_ID = os.environ.get("GEN_INFERENCE_PROFILE_ID")
INDEX = os.environ.get("OPENSEARCH_INDEX", "kb_chunks")
ENDPOINT = os.environ["OPENSEARCH_ENDPOINT"]
CORS_ALLOW_ORIGIN = os.environ.get("CORS_ALLOW_ORIGIN", "*")
