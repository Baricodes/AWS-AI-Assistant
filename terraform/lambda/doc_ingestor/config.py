"""Environment-driven settings for the doc ingestor."""

import os

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "us-east-1")
EMBED_MODEL_ID = os.environ.get(
    "EMBED_MODEL_ID",
    "amazon.titan-embed-text-v2:0",
)
OPENSEARCH_ENDPOINT = os.environ["OPENSEARCH_ENDPOINT"]
OPENSEARCH_INDEX = os.environ.get("OPENSEARCH_INDEX", "kb_chunks")
