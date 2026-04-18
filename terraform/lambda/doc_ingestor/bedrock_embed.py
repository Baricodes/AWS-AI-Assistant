"""Titan embedding calls via Bedrock runtime."""

import json
import logging

from botocore.exceptions import ClientError

from doc_ingestor import clients, config

logger = logging.getLogger(__name__)


def embed(
    text: str,
    dimensions: int | None = None,
    normalize: bool | None = None,
    model_id: str | None = None,
) -> list:
    """Return embedding (list of floats) for text."""
    model_id = model_id or config.EMBED_MODEL_ID

    logger.info(
        (
            "Invoking Bedrock runtime for embedding: model=%s, region=%s, "
            "text_length=%d, dimensions=%s, normalize=%s"
        ),
        model_id,
        config.BEDROCK_REGION,
        len(text),
        str(dimensions),
        str(normalize),
    )

    native_request = {"inputText": text}
    if dimensions is not None:
        native_request["dimensions"] = int(dimensions)
    if normalize is not None:
        native_request["normalize"] = bool(normalize)

    body = json.dumps(native_request)

    try:
        resp = clients.bedrock.invoke_model(modelId=model_id, body=body)
        raw = resp["body"].read()
        payload = json.loads(raw)
        if "embedding" in payload:
            embedding = payload["embedding"]
            logger.info(
                "Successfully generated embedding: dimension=%d", len(embedding)
            )
            return embedding
        if "outputs" in payload and isinstance(payload["outputs"], list):
            for output_item in payload["outputs"]:
                if isinstance(output_item, dict) and "embedding" in output_item:
                    embedding = output_item["embedding"]
                    logger.info(
                        (
                            "Successfully generated embedding from outputs: "
                            "dimension=%d"
                        ),
                        len(embedding),
                    )
                    return embedding
        error_msg = (
            "No 'embedding' found in model response: "
            + json.dumps(payload)[:1000]
        )
        logger.error(error_msg)
        raise RuntimeError(error_msg)
    except ClientError as e:
        error_info = e.response.get("Error", {})
        logger.error("Bedrock invoke_model ClientError: %s", error_info)
        raise
    except Exception as e:
        logger.error("Embed failed: %s - %s", type(e).__name__, str(e))
        raise
