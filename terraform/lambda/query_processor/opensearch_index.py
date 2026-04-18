"""OpenSearch index lifecycle for query path."""

import logging

from query_processor import clients, config

logger = logging.getLogger(__name__)


def ensure_index_exists() -> None:
    """Create the vector index if it doesn't exist."""
    try:
        if clients.os_client.indices.exists(index=config.INDEX):
            logger.info("Index %s already exists", config.INDEX)
            return

        logger.info("Creating index %s", config.INDEX)
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

        clients.os_client.indices.create(index=config.INDEX, body=index_config)
        logger.info("Successfully created index %s", config.INDEX)

    except Exception as e:
        logger.error("Error ensuring index exists: %s", str(e))
