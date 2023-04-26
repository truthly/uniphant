from dataclasses import dataclass
from uuid import uuid4, UUID
from pathlib import Path
from socket import gethostname
from .utils import retrieve_worker_executable_info, get_or_create_unique_id_from_file
from .parse_arguments import parse_arguments

@dataclass(frozen=True)
class WorkerInfo:
    daemonize: bool
    host_id: UUID
    host_id_file: Path
    host_name: str
    process_id: UUID
    root_dir: Path
    secret_dir: Path
    secrets_root: Path
    worker_dir: Path
    worker_id: UUID
    worker_type: str

def worker_info() -> WorkerInfo:
    root_dir, worker_dir, worker_type = retrieve_worker_executable_info()
    worker_id: UUID
    daemonize: bool
    worker_id, daemonize = parse_arguments()
    if worker_id is None:
        worker_id_file = worker_dir / f".{worker_type}.worker_id"
        worker_id = get_or_create_unique_id_from_file(worker_id_file)
    host_id_file = root_dir / ".host_id"
    user_home = Path.home()
    secrets_root = user_home / ".uniphant" / "secrets" / "workers"
    secret_dir = secrets_root / worker_dir.relative_to(root_dir)
    return WorkerInfo(
        daemonize=daemonize,
        host_id=get_or_create_unique_id_from_file(host_id_file),
        host_id_file=host_id_file,
        host_name=gethostname(),
        process_id=uuid4(),
        root_dir=root_dir,
        secret_dir=secret_dir,
        secrets_root=secrets_root,
        worker_dir=worker_dir,
        worker_id=worker_id,
        worker_type=worker_type
    )
