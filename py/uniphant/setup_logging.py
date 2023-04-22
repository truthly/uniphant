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
    # File handler
    fh = logging.FileHandler(log_file)
    fh.setLevel(logging.INFO)
    formatstr = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    formatter = logging.Formatter(formatstr)
    fh.setFormatter(formatter)
    logger.addHandler(fh)
    # Stream handler
    if context.foreground:
        sh = logging.StreamHandler(sys.stdout)
        sh.setLevel(logging.INFO)
        sh.setFormatter(formatter)
        logger.addHandler(sh)
    return logger
