"""Load text from S3 bodies (plain UTF-8 and PDF) and chunk for embedding."""

import logging
import textwrap
from io import BytesIO

from pypdf import PasswordType, PdfReader

logger = logging.getLogger(__name__)


def _is_pdf(key: str, content_type: str | None) -> bool:
    if key.lower().endswith(".pdf"):
        return True
    ct = (content_type or "").split(";", 1)[0].strip().lower()
    return ct == "application/pdf"


def extract_text_from_pdf(body: bytes) -> str:
    """Extract plain text from PDF bytes using pypdf."""
    reader = PdfReader(BytesIO(body), strict=False)
    if reader.is_encrypted:
        if reader.decrypt("") == PasswordType.NOT_DECRYPTED:
            raise ValueError("encrypted PDF requires a password")
    parts: list[str] = []
    for page in reader.pages:
        page_text = page.extract_text()
        if page_text:
            parts.append(page_text.strip())
    return "\n\n".join(parts)


def load_document_text(body: bytes, key: str, content_type: str | None) -> str:
    """Decode S3 object body to plain text; route PDFs through pypdf."""
    if _is_pdf(key, content_type):
        logger.info("Parsing as PDF: key=%s", key)
        return extract_text_from_pdf(body)
    return body.decode("utf-8", errors="ignore")


def chunk_text(text: str, max_len: int = 1200) -> list[str]:
    """Simple character-based chunker."""
    stripped = text.strip()
    if not stripped:
        return []
    chunks = textwrap.wrap(stripped, max_len)
    logger.debug(
        "Chunked text: input length=%d, chunks=%d, max_len=%d",
        len(text),
        len(chunks),
        max_len,
    )
    return chunks
