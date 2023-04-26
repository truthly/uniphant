# Standard library imports
from os import getpid
from sys import exit
from time import sleep
from traceback import format_exc
from typing import Callable, Dict
from uuid import UUID
from logging import Logger

# Related third-party imports
from daemon import DaemonContext
from psycopg2.extensions import connection as Connection

# Local application/library-specific imports
from .worker_info import worker_info, WorkerInfo
from .read_config_files import read_config_files
from .database import connect_database, register_worker, register_process, keepalive_process, delete_process, get_process
from .setup_logging import setup_logging

# Your WorkerFunction should accept the following input parameters:
#
#   connection: psycopg2.extensions.connection
#       object for the PostgreSQL database
#
#   config: Dict[str, str]
#       dictionary containing configuration values (key-value pairs)
# 
#   info: WorkerInfo
#       immutable struct with various worker fields
#
#   logger: logging.Logger
#       object for logging messages
WorkerFunction = Callable[
    [Connection, Dict[str, str], WorkerInfo, Logger],
    None
]

def worker(worker_function: WorkerFunction):
    # Derives worker information
    info: WorkerInfo = worker_info()

    # Read uniphant.conf and secrets.conf config files in all directories
    config: Dict[str, str] = read_config_files(info)

    # Connect to the PostgreSQL database shard
    connection: Connection = connect_database(config)

    # Register worker
    register_worker(connection, info.worker_id, info.worker_type, info.host_id, info.host_name)

    # Check if worker is already running
    if get_process(connection, info.worker_id) is not None:
        print(f"Cannot start {info.worker_type} worker with ID {info.worker_id} since it is already running.")
        exit(1)

    # Start worker
    print(f"Starting {info.worker_type} worker with ID: {info.worker_id}")
    if info.daemonize:
        # Disconnect since daemon will fork and child cannot share database connection with parent.
        connection.close()
        start_daemon(worker_function, config, info)
    else:
        run(worker_function, connection, config, info)

def start_daemon(worker_function: WorkerFunction,
                 config: Dict[str, str],
                 info: WorkerInfo):
    with DaemonContext(working_directory=str(info.worker_dir)):
        connection = connect_database(config)
        run(worker_function, connection, config, info)

def run(worker_function: WorkerFunction,
        connection: Connection,
        config: Dict[str, str],
        info: WorkerInfo):
    logger: Logger = setup_logging(info)
    pid = getpid()
    try:
        logger.info(f"Started PID: {pid}")
        register_process(connection, info.process_id, info.worker_id, pid)
        while should_run(connection, info.process_id):
            worker_function(connection, config, info, logger)
            sleep(1)
    except Exception as e:
        tb = format_exc()
        error = f'{e}\n{tb}'
        logger.error(error)
    finally:
        logger.info(f"Stopped PID: {pid}")
        delete_process(connection, info.process_id)
        connection.close()

def should_run(connection: Connection, process_id: UUID) -> bool:
    # If termination has been requested keepalive_process() will return false.
    return keepalive_process(connection, process_id)
