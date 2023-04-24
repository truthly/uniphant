import psycopg2
from psycopg2.extensions import connection as Connection
from uuid import UUID
from typing import Tuple

def connect() -> Connection:
    connection = psycopg2.connect()
    connection.autocommit = True
    return connection

def register_host(connection: Connection, host_id: UUID, host_name: str) -> None:
    connection.cursor().execute("""
        SELECT register_host(
            host_id := %s,
            host_name := %s
        )
    """, (str(host_id), host_name))

def register_process(connection: Connection, process_id: UUID, worker_id: UUID, pid: int) -> None:
    connection.cursor().execute("""
        SELECT register_process(
            process_id := %s,
            worker_id := %s,
            pid := %s
        )
    """, (str(process_id),str(worker_id),pid))

def keepalive(connection: Connection, process_id: UUID) -> bool:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT keepalive(process_id := %s)
    """, (str(process_id),))
    should_run: bool = cursor.fetchone()[0]
    return should_run

def delete_process(connection: Connection, process_id: UUID) -> None:
    connection.cursor().execute("""
        SELECT delete_process(process_id := %s)
    """, (str(process_id),))

def get_worker_process_id(connection: Connection, worker_id: UUID) -> UUID:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT get_worker_process_id(worker_id := %s)
    """, (str(worker_id),))
    process_id: UUID = cursor.fetchone()[0]
    return process_id

def request_process_termination(connection: Connection, process_id: UUID) -> None:
    connection.cursor().execute("""
        SELECT request_process_termination(process_id := %s)
    """, (str(process_id),))
