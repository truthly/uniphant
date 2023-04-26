from psycopg2 import connect
from psycopg2.extensions import connection as Connection
from uuid import UUID
from typing import Dict, Optional, Tuple

def connect_database(config: Dict[str, str]) -> Connection:
    connection = connect(
        dbname=config.get("PGDATABASE", "uniphant"),
        user=config.get("PGUSER", "uniphant"),
        password=config.get("PGPASSWORD", None),
        host=config.get("PGHOST", "localhost"),
        port=int(config.get("PGPORT", "5432"))
    )
    connection.autocommit = True
    return connection

def register_worker(connection: Connection, worker_id: UUID, worker_type: str, host_id: UUID, host_name: str) -> None:
    connection.cursor().execute("""
        SELECT register_worker(
            worker_id := %s,
            worker_type := %s,
            host_id := %s,
            host_name := %s
        )
    """, (str(worker_id), worker_type, str(host_id), str(host_name)))

def register_process(connection: Connection, process_id: UUID, worker_id: UUID, pid: int) -> None:
    connection.cursor().execute("""
        SELECT register_process(
            process_id := %s,
            worker_id := %s,
            pid := %s
        )
    """, (str(process_id), str(worker_id), pid))

def keepalive_process(connection: Connection, process_id: UUID) -> bool:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT keepalive_process(process_id := %s)
    """, (str(process_id),))
    should_run = cursor.fetchone()[0]
    return should_run

def delete_process(connection: Connection, process_id: UUID) -> None:
    connection.cursor().execute("""
        SELECT delete_process(process_id := %s)
    """, (str(process_id),))

def get_process(connection: Connection, worker_id: UUID) -> UUID:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT get_process(worker_id := %s)
    """, (str(worker_id),))
    process_id = cursor.fetchone()[0]
    return process_id

def terminate_process(connection: Connection, process_id: UUID) -> None:
    connection.cursor().execute("""
        SELECT terminate_process(process_id := %s)
    """, (str(process_id),))

def start_worker_next(connection, host_id: UUID) -> Optional[Tuple[UUID, str]]:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT
            worker_id,
            worker_type
        FROM start_worker_next(%s)
    """, (str(host_id),))
    worker_id, worker_type = cursor.fetchone()
    if worker_id and worker_type:
        return worker_id, worker_type
    else:
        return None

def kill_worker_next(connection, host_id: UUID) -> Optional[Tuple[UUID, str, str, int]]:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT
            worker_id,
            worker_type,
            command,
            pid
        FROM kill_worker_next(%s)
    """, (str(host_id),))
    worker_id, worker_type, command, pid = cursor.fetchone()
    if worker_id and worker_type and command and pid:
        return worker_id, worker_type, command, pid
    else:
        return None

def ping_worker_next(connection, host_id: UUID) -> Optional[Tuple[UUID, str, UUID, int]]:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT
            worker_id,
            worker_type,
            process_id,
            pid
        FROM ping_worker_next(%s)
    """, (str(host_id),))
    worker_id, worker_type, process_id, pid = cursor.fetchone()
    if worker_id and worker_type and process_id and pid:
        return worker_id, worker_type, process_id, pid
    else:
        return None
