import os
import uuid
import socket
import inspect
from .worker_context import WorkerContext
from typing import Tuple
from pathlib import Path
from uuid import UUID

def init_worker(worker_id: UUID, foreground: bool) -> WorkerContext:
    root_dir, script_dir, worker_type = get_script_details()
    host_id_file = root_dir / ".host_id"
    user_home = Path.home()
    secrets_root = user_home / ".uniphant" / "secrets"
    secret_dir = secrets_root / script_dir.relative_to(root_dir)
    return WorkerContext(
        foreground=foreground,
        host_id=get_or_create_host_id(host_id_file),
        host_id_file=host_id_file,
        host_name=socket.gethostname(),
        process_id=uuid.uuid4(),
        root_dir=root_dir,
        script_dir=script_dir,
        secret_dir=secret_dir,
        secrets_root=secrets_root,
        worker_id=worker_id,
        worker_type=worker_type
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

def get_calling_file_path() -> Path:
    # Get the entire call stack
    stack = inspect.stack()

    # Get the last frame_info in the call stack (the top-level script)
    frame_info = stack[-1]

    # Return the file path of the top-level script
    return Path(frame_info.filename).resolve()
