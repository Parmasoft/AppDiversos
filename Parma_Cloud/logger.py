from __future__ import annotations

import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path

from config import ConfigLog


class _FiltroConsole(logging.Filter):
    """Oculta no console registros destinados somente ao arquivo de log."""

    def filter(self, record: logging.LogRecord) -> bool:
        return not bool(getattr(record, "somente_arquivo", False))


def configurar_logger(config: ConfigLog, usar_console: bool = True) -> logging.Logger:
    logger = logging.getLogger("ParmaCloudSync")
    logger.setLevel(getattr(logging, config.nivel, logging.INFO))
    logger.propagate = False

    if logger.handlers:
        return logger

    formato = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    caminho_log = Path(__file__).resolve().parent / config.arquivo
    caminho_log.parent.mkdir(parents=True, exist_ok=True)

    arquivo_handler = RotatingFileHandler(
        caminho_log,
        maxBytes=config.rotacao_mb * 1024 * 1024,
        backupCount=config.backups,
        encoding="utf-8",
    )
    arquivo_handler.setFormatter(formato)

    logger.addHandler(arquivo_handler)

    if usar_console:
        console_handler = logging.StreamHandler(stream=sys.stdout)
        console_handler.setFormatter(formato)
        console_handler.addFilter(_FiltroConsole())
        logger.addHandler(console_handler)

    return logger
