import os
import sys
import uuid
import socket
from .worker_context import WorkerContext
from typing import Tuple
from pathlib import Path
from uuid import UUID

def init_worker(worker_id: UUID, foreground: bool) -> WorkerContext:
    root_dir, worker_dir, worker_type = retrieve_worker_executable_info()
    host_id_file = root_dir / ".host_id"
    user_home = Path.home()
    secrets_root = user_home / ".uniphant" / "secrets" / "workers"
    secret_dir = secrets_root / worker_dir.relative_to(root_dir)
    return WorkerContext(
        foreground=foreground,
        host_id=get_or_create_host_id(host_id_file),
        host_id_file=host_id_file,
        host_name=socket.gethostname(),
        process_id=uuid.uuid4(),
        root_dir=root_dir,
        worker_dir=worker_dir,
        secret_dir=secret_dir,
        secrets_root=secrets_root,
        worker_id=worker_id,
        worker_type=worker_type
    )

def retrieve_worker_executable_info():
    current_exe_path = Path(sys.argv[0]).resolve()
    worker_dir = current_exe_path.parent
    path_components = current_exe_path.parts
    workers_count = path_components.count('workers')
    if workers_count == 0:
        raise ValueError("Worker executable must reside under a directory named 'workers'")
    elif workers_count > 1:
        raise ValueError("There must be only one 'workers' directory in the path")
    workers_index = path_components.index('workers')
    root_dir = Path(*path_components[:workers_index + 1])
    worker_type_parts = path_components[workers_index + 1:-1]
    worker_type = ".".join(worker_type_parts)
    if current_exe_path.suffix:
        worker_type = worker_type[:-len(current_exe_path.suffix)]
    return root_dir, worker_dir, worker_type

def get_or_create_host_id(host_id_file: Path) -> UUID:
    if not host_id_file.exists():
        # Create a temporary file with a unique name
        host_id = uuid.uuid4()
        temp_host_id_file = host_id_file.with_suffix("." + str(host_id))
        temp_host_id_file.write_text(str(host_id))
        try:
            # Atomically rename the temporary file to the final file
            os.rename(str(temp_host_id_file), str(host_id_file))
        except FileExistsError:
            # Another process has already created the host_id_file, so it's safe to ignore this error
            pass
        finally:
            # Clean up the temporary file if it still exists
            temp_host_id_file.unlink(missing_ok=True)
    # Read the host_id from the file
    host_id = UUID(host_id_file.read_text())
    return host_id
