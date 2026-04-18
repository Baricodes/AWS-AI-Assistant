"""Lambda handler and S3 → chunk → embed → index orchestration."""

import hashlib
import logging

from doc_ingestor import config
from doc_ingestor.bedrock_embed import embed
from doc_ingestor.clients import s3
from doc_ingestor.document_io import chunk_text, load_document_text
from common.logging_utils import BufferedLogHandler
from doc_ingestor.opensearch_index import ensure_index_exists, index_chunk

logger = logging.getLogger(__name__)


def handler(event, context):
    """AWS Lambda handler for ingesting S3 documents into OpenSearch."""
    root_logger = logging.getLogger()
    for h in list(root_logger.handlers):
        root_logger.removeHandler(h)
    buf_handler = BufferedLogHandler()
    root_logger.addHandler(buf_handler)
    root_logger.setLevel(getattr(logging, config.LOG_LEVEL, logging.INFO))

    logger.info(
        "Lambda invocation started: record_count=%d",
        len(event.get("Records", [])),
    )

    try:
        ensure_index_exists()

        records = event.get("Records", [])
        for record_idx, record in enumerate(records):
            bucket = record["s3"]["bucket"]["name"]
            key = record["s3"]["object"]["key"]
            logger.info(
                "Processing S3 record %d/%d: bucket=%s, key=%s",
                record_idx + 1,
                len(records),
                bucket,
                key,
            )

            obj = s3.get_object(Bucket=bucket, Key=key)
            raw = obj["Body"].read()
            content_type = obj.get("ContentType")
            try:
                text = load_document_text(raw, key, content_type)
            except Exception as e:
                logger.error(
                    "Failed to extract text from object: key=%s error=%s",
                    key,
                    e,
                    exc_info=True,
                )
                raise

            logger.info(
                "Document loaded: key=%s, raw_bytes=%d, text_chars=%d",
                key,
                len(raw),
                len(text),
            )

            doc_id = hashlib.md5(key.encode()).hexdigest()
            logger.debug("Generated doc_id: %s for key: %s", doc_id, key)
            meta = {"source": "s3", "s3_key": key}

            chunks = chunk_text(text)
            if not chunks:
                logger.warning(
                    "No text chunks produced (empty or whitespace-only): key=%s",
                    key,
                )
                continue

            logger.info(
                "Chunking complete: doc_id=%s, total_chunks=%d",
                doc_id,
                len(chunks),
            )

            for i, chunk_text_value in enumerate(chunks):
                logger.info(
                    "Processing chunk %d/%d for doc_id=%s",
                    i + 1,
                    len(chunks),
                    doc_id,
                )
                vec = embed(chunk_text_value)
                index_chunk(doc_id, i, chunk_text_value, vec, meta)

            logger.info(
                "Successfully processed document: doc_id=%s, chunks_indexed=%d",
                doc_id,
                len(chunks),
            )

        logger.info("Lambda invocation completed successfully")
        return {"ok": True}
    finally:
        try:
            combined = buf_handler.get_value()
            if combined:
                print(combined)
        except Exception:
            pass
