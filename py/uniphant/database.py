import psycopg2
from psycopg2.extensions import connection as Connection
from uuid import UUID
from typing import Tuple

def connect() -> Connection:
    connection = psycopg2.connect()
    connection.autocommit = True
    return connection

def delete_process(connection: Connection, process_id: UUID) -> None:
    connection.cursor().execute("""
        SELECT delete_process(%s)
    """, (str(process_id),))

def register_host(connection: Connection, host_id: UUID, host_name: str) -> None:
    connection.cursor().execute("""
        SELECT register_host(%s,%s)
    """, (str(host_id), host_name))

def register_process(connection: Connection, process_id: UUID, worker_id: UUID, pid: int) -> None:
    connection.cursor().execute("""
        SELECT register_process(%s,%s,%s)
    """, (str(process_id),str(worker_id),pid))

def get_existing_process_info(connection: Connection, host_id: UUID, worker_id: UUID) -> Tuple[UUID, int]:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT process_id, pid FROM get_existing_process_info(%s,%s)
    """, (str(host_id),str(worker_id)))
    tuple = cursor.fetchone()
    if tuple is None:
        return
    process_id: UUID = tuple[0]
    pid: int = tuple[1]
    return process_id, pid

def keepalive(connection: Connection, process_id: UUID) -> bool:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT keepalive(%s)
    """, (str(process_id),))
    return cursor.fetchone()[0]
