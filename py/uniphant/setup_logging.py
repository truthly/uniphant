import sys
import logging
from .worker_context import WorkerContext

def setup_logging(context: WorkerContext) -> logging.Logger:
    log_dir = context.root_dir / "log" / context.worker_type
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / (str(context.worker_id) + ".log")
    logger_name = str(context.worker_id) + " " + context.worker_type
    logger = logging.getLogger(logger_name)
    logger.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    if context.foreground:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
    return logger
