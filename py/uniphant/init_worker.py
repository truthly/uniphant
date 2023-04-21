import uuid
import socket
from filelock import FileLock
import inspect
from .worker_state import WorkerState
from typing import Tuple
from pathlib import Path

def init_worker(worker_id: str, foreground: bool) -> WorkerState:
    root_dir, script_dir, worker_type = get_script_details()
    lock_file = root_dir / ".lock"
    host_id_file = root_dir / ".host_id"
    user_home = Path.home()
    secrets_root = user_home / ".uniphant" / "secrets"
    secret_dir = secrets_root / script_dir.relative_to(root_dir)
    pid_dir = root_dir / "pid" / worker_type
    pid_dir.mkdir(parents=True, exist_ok=True)
    return WorkerState(
        root_dir=root_dir,
        script_dir=script_dir,
        worker_type=worker_type,
        lock_file=lock_file,
        host_id_file=host_id_file,
        host_id=get_or_create_host_id(lock_file, host_id_file),
        process_id=str(uuid.uuid4()),
        host_name=socket.gethostname(),
        secrets_root=secrets_root,
        secret_dir=secret_dir,
        worker_id=worker_id,
        foreground=foreground,
        pid_file=pid_dir / f"{worker_id}.pid"
    )

def get_script_details() -> Tuple[Path, Path, str]:
    script_path = get_calling_file_path()
    script_dir = script_path.parent
    path_components = script_path.parts
    workers_count = path_components.count("workers")
    if workers_count == 0:
        raise ValueError("The worker script must reside under 'workers'")
    elif workers_count > 1:
        raise ValueError("There should be only one 'workers' in the path")
    workers_index = path_components.index("workers")
    root_dir = Path(*path_components[:workers_index])
    worker_type_components = path_components[workers_index + 1:]
    worker_type = ".".join(worker_type_components).rstrip(".py")
    return root_dir, script_dir, worker_type

def get_or_create_host_id(lock_file: Path, host_id_file: Path):
    if not host_id_file.exists():
        with FileLock(str(lock_file)):
            if not host_id_file.exists():
                host_id = str(uuid.uuid4())
                host_id_file.write_text(host_id)
    with FileLock(str(lock_file)):
        host_id = host_id_file.read_text()
        return host_id

def get_calling_file_path() -> Path:
    # Get the entire call stack
    stack = inspect.stack()

    # Get the last frame_info in the call stack (the top-level script)
    frame_info = stack[-1]

    # Return the file path of the top-level script
    return Path(frame_info.filename).resolve()
