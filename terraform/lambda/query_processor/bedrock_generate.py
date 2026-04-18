"""Answer generation via Bedrock (Claude / Anthropic message format)."""

import json
import logging

from query_processor import clients, config

logger = logging.getLogger(__name__)


def answer_with_context(question: str, contexts: list[dict]) -> str:
    """Generate an answer using retrieved contexts via Bedrock."""
    model_id_to_use = (
        config.GEN_INFERENCE_PROFILE_ID
        if config.GEN_INFERENCE_PROFILE_ID
        else config.GEN_MODEL_ID
    )
    logger.info(
        (
            "Generating answer: model=%s, question_length=%d, "
            "context_count=%d"
        ),
        model_id_to_use,
        len(question),
        len(contexts),
    )
    system = (
        "You are an AWS tutor. Only answer using the provided Context. "
        "If the Context is insufficient or off-topic, say you don't know. "
        "Always include citations as [Snippet N] where N matches the provided snippets. "
        "Never use external knowledge."
    )
    context_blob = "\n\n".join(
        [f"Snippet {i + 1}:\n{c['text']}" for i, c in enumerate(contexts)]
    )

    prompt = f"{system}\n\nQuestion:\n{question}\n\nContext:\n{context_blob}\n\nAnswer:"
    request_body = {
        "messages": [
            {"role": "user", "content": [{"type": "text", "text": prompt}]}
        ],
        "max_tokens": 500,
    }
    if "anthropic" in model_id_to_use.lower():
        request_body["anthropic_version"] = "bedrock-2023-05-31"
    body = json.dumps(request_body)
    try:
        resp = clients.bedrock.invoke_model(modelId=model_id_to_use, body=body)
        payload = json.loads(resp["body"].read())
        answer = None
        if "anthropic" in model_id_to_use.lower():
            content = payload.get("content") or []
            if content and isinstance(content, list) and "text" in content[0]:
                answer = content[0]["text"]
        else:
            output = payload.get("output") or []
            if (
                output
                and isinstance(output, list)
                and output[0].get("content")
                and isinstance(output[0]["content"], list)
                and output[0]["content"][0].get("text") is not None
            ):
                answer = output[0]["content"][0]["text"]
        if answer is None:
            raise ValueError("Unexpected model response format")
        logger.info("Successfully generated answer: answer_length=%d", len(answer))
        return answer
    except Exception as e:
        logger.error(
            "Answer generation failed: %s - %s", type(e).__name__, str(e)
        )
        raise
