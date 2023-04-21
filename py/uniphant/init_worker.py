import os
import uuid
import socket
from filelock import FileLock
import inspect
from .worker_state import WorkerState

def init_worker(worker_id: str, foreground: bool) -> WorkerState:
    root_dir, script_dir, worker_type = get_script_details()
    lock_file = os.path.join(root_dir, ".lock")
    host_id_file = os.path.join(root_dir, ".host_id")
    user_home = os.path.expanduser("~")
    secrets_root = os.path.join(user_home, ".uniphant", "secrets")
    secret_dir = os.path.join(secrets_root, os.path.relpath(script_dir, root_dir))
    pid_dir = os.path.join(root_dir, "pid", worker_type)
    if not os.path.exists(pid_dir):
        os.makedirs(pid_dir)
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
        pid_file=os.path.join(pid_dir, worker_id + ".pid")
    )

def get_script_details():
    script_path = get_calling_file_path()
    script_dir = os.path.dirname(script_path)
    path_components = script_path.split(os.path.sep)
    workers_count = path_components.count("workers")
    if workers_count == 0:
        raise ValueError("The worker script must reside under 'workers'")
    elif workers_count > 1:
        raise ValueError("There should be only one 'workers' in the path")
    workers_index = path_components.index("workers")
    root_dir = os.path.join(os.path.sep, *path_components[:workers_index])
    worker_type_components = path_components[workers_index + 1:]
    worker_type = ".".join(worker_type_components).rstrip(".py")
    return root_dir, script_dir, worker_type

def get_or_create_host_id(lock_file, host_id_file):
    if not os.path.exists(host_id_file):
        with FileLock(lock_file):
            if not os.path.exists(host_id_file):
                host_id = str(uuid.uuid4())
                with open(host_id_file, "w") as f:
                    f.write(host_id)
    with FileLock(lock_file):
        with open(host_id_file, "r") as f:
            host_id = f.read()
            return host_id

def get_calling_file_path():
    # Get the entire call stack
    stack = inspect.stack()

    # Get the last frame_info in the call stack (the top-level script)
    frame_info = stack[-1]

    # Return the file path of the top-level script
    return os.path.abspath(frame_info.filename)
