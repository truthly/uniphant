from sys import argv
from time import sleep
from os import kill, rename
from uuid import uuid4, UUID
from pathlib import Path
from psycopg2.extensions import connection as Connection
from .database import terminate_process, get_process

def is_valid_uuid(text: str) -> bool:
    try:
        UUID(text)
        return True
    except ValueError:
        return False

def is_pid_alive(pid: int) -> bool:
    try:
        kill(pid, 0)
    except OSError:
        return False
    return True

def stop_worker_process(connection: Connection, worker_id: UUID, process_id: UUID) -> None:
    terminate_process(connection, process_id)
    sleep(1)
    while get_process(connection, worker_id) is not None:
        print(f"Waiting for process {process_id} to die.")
        sleep(1)

def retrieve_worker_executable_info():
    current_exe_path = Path(argv[0]).resolve()
    worker_dir = current_exe_path.parent
    path_components = current_exe_path.parts
    workers_count = path_components.count('workers')
    if workers_count == 0:
        raise ValueError("Worker executable must reside under a directory named 'workers'")
    elif workers_count > 1:
        raise ValueError("There must be only one 'workers' directory in the path")
    workers_index = path_components.index('workers')
    root_dir = Path(*path_components[:workers_index + 1])
    worker_type = ".".join(current_exe_path.relative_to(root_dir).parts)
    return root_dir, worker_dir, worker_type

def get_or_create_unique_id_from_file(file_path: Path) -> UUID:
    if not file_path.exists():
        # Create a temporary file with a unique name
        unique_id = uuid4()
        temp_file_path = file_path.with_suffix("." + str(unique_id))
        temp_file_path.write_text(str(unique_id))
        try:
            # Atomically rename the temporary file to the final file
            rename(str(temp_file_path), str(file_path))
        except FileExistsError:
            # Another process has already created the file_path, so it's safe to ignore this error
            pass
        finally:
            # Clean up the temporary file if it still exists
            temp_file_path.unlink(missing_ok=True)
    # Read the unique_id from the file
    unique_id = UUID(file_path.read_text())
    return unique_id
