"""Query processor Lambda package. Entry point: ``handler`` for Terraform ``query_processor.handler``."""

from query_processor.main import handler

__all__ = ["handler"]
