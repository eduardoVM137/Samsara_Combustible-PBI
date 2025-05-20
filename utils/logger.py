# utils/logger.py
import logging
import os

def setup_logger():
    logger = logging.getLogger("samsara_sync")
    logger.setLevel(logging.INFO)

    if not logger.handlers:
        log_path = os.path.join(os.path.dirname(__file__), "../../samsara_sync.log")
        
        file_handler = logging.FileHandler(log_path, encoding="utf-8")
        console_handler = logging.StreamHandler()

        formatter = logging.Formatter('[%(asctime)s] %(levelname)s: %(message)s')
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)

        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

    return logger

logger = setup_logger()
