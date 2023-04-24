import psycopg2
from psycopg2.extensions import connection as Connection
from uuid import UUID
from typing import Tuple
from typing import Optional

def connect(dbname: Optional[str] = None,
            user: Optional[str] = None,
            password: Optional[str] = None,
            host: Optional[str] = None,
            port: Optional[int] = None) -> Connection:
    connection = psycopg2.connect(
        dbname=dbname,
        user=user,
        password=password,
        host=host,
        port=port
    )
    connection.autocommit = True
    return connection

def register_host(connection: Connection, host_id: UUID, host_name: str) -> None:
    connection.cursor().execute("""
        SELECT register_host(
            host_id := %(host_id)s,
            host_name := %(host_name)s
        )
    """, {"host_id": str(host_id), "host_name": host_name})

def register_process(connection: Connection, process_id: UUID, worker_id: UUID, pid: int) -> None:
    connection.cursor().execute("""
        SELECT register_process(
            process_id := %(process_id)s,
            worker_id := %(worker_id)s,
            pid := %(pid)s
        )
    """, {"process_id": str(process_id), "worker_id": str(worker_id), "pid": pid})

def keepalive(connection: Connection, process_id: UUID) -> bool:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT keepalive(process_id := %(process_id)s)
    """, {"process_id": str(process_id)})
    should_run = cursor.fetchone()[0]
    return should_run

def delete_process(connection: Connection, process_id: UUID) -> None:
    connection.cursor().execute("""
        SELECT delete_process(process_id := %(process_id)s)
    """, {"process_id": str(process_id)})

def get_worker_process_id(connection: Connection, worker_id: UUID) -> UUID:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT get_worker_process_id(worker_id := %(worker_id)s)
    """, {"worker_id": str(worker_id)})
    process_id = cursor.fetchone()[0]
    return process_id

def request_process_termination(connection: Connection, process_id: UUID) -> None:
    connection.cursor().execute("""
        SELECT request_process_termination(process_id := %(process_id)s)
    """, {"process_id": str(process_id)})
