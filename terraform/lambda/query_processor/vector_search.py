"""kNN vector search against the knowledge index."""

import logging

from query_processor import clients, config

logger = logging.getLogger(__name__)


def search(vec: list, k: int = 5) -> list[dict]:
    """Perform a kNN vector search in OpenSearch."""
    logger.info(
        "Searching OpenSearch: index=%s, k=%d, vector_dim=%d",
        config.INDEX,
        k,
        len(vec),
    )
    query = {"knn": {"embedding": {"vector": vec, "k": k}}}
    res = clients.os_client.search(
        index=config.INDEX, body={"size": k, "query": query}
    )
    hits = res.get("hits", {}).get("hits", [])
    total_field = res.get("hits", {}).get("total")
    total_hits = (
        total_field.get("value") if isinstance(total_field, dict) else total_field
    )
    sources = [
        h["_source"].get("s3_key") or h["_source"].get("source") for h in hits
    ]
    logger.info(
        "Search completed: total_hits=%s, returned=%d, sources=%s",
        total_hits,
        len(hits),
        sources,
    )
    return [
        {
            "text": h.get("_source", {}).get("chunk_text", ""),
            "source": (
                h.get("_source", {}).get("s3_key")
                or h.get("_source", {}).get("source")
            ),
            "score": h.get("_score"),
        }
        for h in hits
    ]
