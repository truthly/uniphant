from dataclasses import dataclass
from pathlib import Path
from uuid import UUID

@dataclass(frozen=True)
class WorkerContext:
    foreground: bool
    host_id: UUID
    host_id_file: Path
    host_name: str
    process_id: UUID
    root_dir: Path
    script_dir: Path
    secret_dir: Path
    secrets_root: Path
    worker_id: UUID
    worker_type: str
