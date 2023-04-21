from dataclasses import dataclass

@dataclass
class WorkerState:
    root_dir: str
    script_dir: str
    worker_type: str
    lock_file: str
    host_id_file: str
    host_id: str
    process_id: str
    host_name: str
    secrets_root: str
    secret_dir: str
    worker_id: str
    foreground: bool
    pid_file: str
