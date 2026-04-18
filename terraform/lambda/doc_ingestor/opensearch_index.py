"""OpenSearch index lifecycle and document writes."""

import logging

from doc_ingestor import clients, config

logger = logging.getLogger(__name__)


def ensure_index_exists() -> None:
    """Create the vector index if it doesn't exist."""
    try:
        if clients.os_client.indices.exists(index=config.OPENSEARCH_INDEX):
            logger.info("Index %s already exists", config.OPENSEARCH_INDEX)
            return

        logger.info("Creating index %s", config.OPENSEARCH_INDEX)
        index_config = {
            "settings": {"index.knn": True},
            "mappings": {
                "properties": {
                    "embedding": {
                        "type": "knn_vector",
                        "dimension": 1024,
                        "space_type": "cosinesimil",
                        "mode": "on_disk",
                        "compression_level": "16x",
                        "method": {
                            "name": "hnsw",
                            "engine": "faiss",
                            "parameters": {"m": 16, "ef_construction": 100},
                        },
                    },
                    "chunk_text": {"type": "text"},
                    "doc_id": {"type": "keyword"},
                    "chunk_id": {"type": "integer"},
                    "title": {"type": "text"},
                    "section": {"type": "text"},
                    "source": {"type": "keyword"},
                    "s3_key": {"type": "keyword"},
                    "url": {"type": "keyword"},
                    "tags": {"type": "keyword"},
                    "token_count": {"type": "integer"},
                    "created_at": {"type": "date"},
                    "updated_at": {"type": "date"},
                }
            },
        }

        clients.os_client.indices.create(
            index=config.OPENSEARCH_INDEX, body=index_config
        )
        logger.info("Successfully created index %s", config.OPENSEARCH_INDEX)

    except Exception as e:
        logger.error("Error ensuring index exists: %s", str(e))


def index_chunk(
    doc_id: str,
    chunk_id: int,
    chunk_text_value: str,
    vec: list,
    meta: dict,
) -> None:
    """Index a single chunk into OpenSearch."""
    logger.debug(
        ("Indexing chunk: doc_id=%s, chunk_id=%s, text_length=%d, embedding_dim=%d"),
        doc_id,
        str(chunk_id),
        len(chunk_text_value),
        len(vec),
    )
    body = {
        "doc_id": doc_id,
        "chunk_id": chunk_id,
        "chunk_text": chunk_text_value,
        "embedding": vec,
        **meta,
    }
    clients.os_client.index(index=config.OPENSEARCH_INDEX, body=body)
    logger.info(
        "Successfully indexed chunk: doc_id=%s, chunk_id=%s",
        doc_id,
        str(chunk_id),
    )
