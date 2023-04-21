from dataclasses import dataclass
from pathlib import Path

@dataclass
class WorkerState:
    root_dir: Path
    script_dir: Path
    worker_type: str
    lock_file: Path
    host_id_file: Path
    host_id: str
    process_id: str
    host_name: str
    secrets_root: Path
    secret_dir: Path
    worker_id: str
    foreground: bool
    pid_file: Path
