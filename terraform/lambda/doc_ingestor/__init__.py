"""Doc ingestor Lambda package. Entry point: ``handler`` for Terraform ``doc_ingestor.handler``."""

from doc_ingestor.main import handler

__all__ = ["handler"]
