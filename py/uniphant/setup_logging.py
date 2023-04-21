import sys
import logging

def setup_logging(state):
    log_dir = state.root_dir / "log" / state.worker_type
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / (state.worker_id + ".log")
    logger_name = state.worker_id + " " + state.worker_type
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
    if state.foreground:
        sh = logging.StreamHandler(sys.stdout)
        sh.setLevel(logging.INFO)
        sh.setFormatter(formatter)
        logger.addHandler(sh)
    return logger
