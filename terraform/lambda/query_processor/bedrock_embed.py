"""Query embedding via Bedrock Titan."""

import json
import logging

from query_processor import clients, config

logger = logging.getLogger(__name__)


def embed(text: str) -> list:
    """Generate an embedding for the provided text via Bedrock."""
    logger.info(
        "Generating embedding: model=%s, text_length=%d",
        config.EMBED_MODEL_ID,
        len(text),
    )
    try:
        body = json.dumps({"inputText": text})
        resp = clients.bedrock.invoke_model(modelId=config.EMBED_MODEL_ID, body=body)
        payload = json.loads(resp["body"].read())
        embedding = payload["embedding"]
        logger.info("Successfully generated embedding: dimension=%d", len(embedding))
        return embedding
    except Exception as e:
        logger.error("Embedding failed: %s - %s", type(e).__name__, str(e))
        raise
