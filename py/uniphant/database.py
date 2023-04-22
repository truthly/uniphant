import psycopg2
from psycopg2.extensions import connection as Connection
from uuid import UUID

def connect(process_id: UUID) -> Connection:
    params = {"application_name": str(process_id)}
    connection = psycopg2.connect(**params)
    connection.autocommit = True
    return connection

def disconnect(connection: Connection) -> None:
    connection.cursor().execute("""
        SELECT disconnect()
    """)
    connection.close()

def keepalive(connection: Connection) -> bool:
    cursor = connection.cursor()
    cursor.execute("""
        SELECT keepalive()
    """)
    return cursor.fetchone()[0]

def register_process(connection: Connection, worker_id: UUID) -> None:
    connection.cursor().execute("""
        SELECT register_process(%s)
    """, (str(worker_id),))

def register_host(connection: Connection, host_id: UUID, host_name: str) -> None:
    connection.cursor().execute("""
        SELECT register_host(%s,%s)
    """, (str(host_id), host_name))
