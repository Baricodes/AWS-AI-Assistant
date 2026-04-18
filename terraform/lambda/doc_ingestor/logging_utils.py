"""Buffered logging used so logs flush once per invocation."""

import logging


class BufferedLogHandler(logging.Handler):
    def __init__(self):
        super().__init__()
        self._records = []
        self.setFormatter(
            logging.Formatter(
                "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            )
        )

    def emit(self, record):
        try:
            self._records.append(self.format(record))
        except Exception:
            pass

    def get_value(self):
        return "\n".join(self._records)
