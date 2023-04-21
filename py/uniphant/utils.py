import time
import signal
from pathlib import Path
import uuid
import os

def is_valid_uuid(text: str) -> bool:
    try:
        uuid.UUID(text)
        return True
    except ValueError:
        return False

def is_pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True

def get_pid_for_running_process(pid_file: Path) -> int:
    if not pid_file.exists():
        return None
    else:
        with pid_file.open("r") as f:
            pid = int(f.read())
            if is_pid_alive(pid):
                return pid
            else:
                pid_file.unlink()
                return None

def stop_running_process(pid_file: Path) -> None:
    pid = get_pid_for_running_process(pid_file)
    os.kill(pid, signal.SIGTERM)
    time.sleep(0.2)
    while get_pid_for_running_process(pid_file) is not None:
        print(f"Waiting for pid {pid} to die.")
        time.sleep(1)
