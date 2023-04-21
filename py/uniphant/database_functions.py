import psycopg2
from psycopg2.extensions import connection as Connection

def connect_to_database(process_id: str) -> Connection:
    params = {"application_name": process_id}
    connection = psycopg2.connect(**params)
    connection.autocommit = True
    return connection

def disconnect_from_database(connection: Connection) -> None:
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

def register_process(connection: Connection, worker_id: str) -> None:
    connection.cursor().execute("""
        SELECT register_process(%s)
    """, (worker_id,))

def register_host(connection: Connection, host_id: str, host_name: str) -> None:
    connection.cursor().execute("""
        SELECT register_host(%s,%s)
    """, (host_id, host_name))
