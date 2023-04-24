import time
import uuid
import os
from psycopg2.extensions import connection as Connection
from uuid import UUID
from .database import request_process_termination, get_worker_process_id

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

def stop_worker_process(connection: Connection, worker_id: UUID, process_id: UUID) -> None:
    request_process_termination(connection, process_id)
    time.sleep(1)
    while get_worker_process_id(connection, worker_id) is not None:
        print(f"Waiting for process {process_id} to die.")
        time.sleep(1)
