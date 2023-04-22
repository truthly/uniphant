import time
import signal
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

def stop_running_process(pid: int) -> None:
    os.kill(pid, signal.SIGTERM)
    time.sleep(0.2)
    while is_pid_alive(pid):
        print(f"Waiting for pid {pid} to die.")
        time.sleep(1)
