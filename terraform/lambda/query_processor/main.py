"""Lambda handler: OPTIONS, embed question, search, generate answer."""

import json
import logging
import os

from query_processor import config
from query_processor.bedrock_embed import embed
from query_processor.bedrock_generate import answer_with_context
from query_processor.http_response import CORS_HEADERS, response
from common.logging_utils import BufferedLogHandler
from query_processor.opensearch_index import ensure_index_exists
from query_processor.vector_search import search

logger = logging.getLogger(__name__)


def handler(event, ctx):
    """AWS Lambda handler for query answering over vector search."""
    root_logger = logging.getLogger()
    for h in list(root_logger.handlers):
        root_logger.removeHandler(h)
    buf_handler = BufferedLogHandler()
    root_logger.addHandler(buf_handler)
    root_logger.setLevel(getattr(logging, config.LOG_LEVEL, logging.INFO))

    logger.info("Lambda invocation started for query processing")

    try:
        method = (
            (event.get("requestContext", {}).get("http", {}) or {}).get("method", "")
        ).upper()
        if method == "OPTIONS":
            return {"statusCode": 204, "headers": CORS_HEADERS, "body": ""}

        ensure_index_exists()

        body = json.loads(event.get("body") or "{}")
        question = body.get("question", "").strip()
        if len(question) > 4000:
            question = question[:4000]
        if not question:
            logger.error(
                "Validation failed: question is required but was empty or missing"
            )
            return response(400, {"error": "question required"})

        logger.info(
            "Query received: question='%s...' (length=%d)",
            question[:100],
            len(question),
        )

        qvec = embed(question)
        logger.info("Question embedding generation complete")

        contexts = search(qvec, k=5)
        logger.info("Search completed: found %d contexts", len(contexts))

        answer = answer_with_context(question, contexts)
        logger.info("Answer generation complete")

        logger.info("Lambda invocation completed successfully")
        return response(
            200,
            {
                "answer": answer,
                "sources": [
                    {"snippet_index": i + 1, **c} for i, c in enumerate(contexts)
                ],
            },
        )
    except Exception as e:
        logger.error("Unhandled error: %s - %s", type(e).__name__, str(e))
        if os.environ.get("DEBUG_PUBLIC_ERRORS", "false").lower() in (
            "1",
            "true",
            "yes",
        ):
            try:
                return response(
                    500,
                    {
                        "error": "internal_error",
                        "error_type": type(e).__name__,
                        "message": str(e)[:500],
                    },
                )
            except Exception:
                pass
        return response(500, {"error": "internal_error"})
    finally:
        try:
            combined = buf_handler.get_value()
            if combined:
                print(combined)
        except Exception:
            pass
