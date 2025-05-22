import logging
import os
from pathlib import Path

def setup_logger():
    logger = logging.getLogger("samsara_sync")
    logger.setLevel(logging.INFO)

    if not logger.hasHandlers():
        # Ruta absoluta del log, junto al script principal
        base_dir = Path(__file__).resolve().parent.parent
        log_path = base_dir / "samsara_sync.log"

        # Handler para archivo
        file_handler = logging.FileHandler(log_path, encoding="utf-8")
        
        # Handler para consola
        console_handler = logging.StreamHandler()

        # Formato común
        formatter = logging.Formatter("[%(asctime)s] %(levelname)s: %(message)s", "%Y-%m-%d %H:%M:%S")
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)

        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

        # OPCIONAL: Para rotación de logs cada cierto tamaño
        # from logging.handlers import RotatingFileHandler
        # rotating_handler = RotatingFileHandler(log_path, maxBytes=5_000_000, backupCount=3, encoding='utf-8')
        # rotating_handler.setFormatter(formatter)
        # logger.addHandler(rotating_handler)

    return logger

logger = setup_logger()
