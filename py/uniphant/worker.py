# Standard library imports
import os
import sys
import time
import traceback
from typing import Callable, Dict
from uuid import UUID

# Related third-party imports
import daemon
from psycopg2.extensions import connection as Connection
from logging import Logger

# Local application/library-specific imports
from .worker_context import WorkerContext
from .init_worker import init_worker
from .setup_logging import setup_logging
from .read_config_files import read_config_files
from .parse_arguments import parse_arguments
from .database import connect, delete_process, keepalive, register_process, register_host, get_existing_process_info
from .utils import is_pid_alive, stop_running_process

# Your WorkerFunction should accept the following input parameters:
#
#   connection: psycopg2.extensions.connection
#       object for the PostgreSQL database
#
#   config: Dict[str, str]
#       dictionary containing configuration values (key-value pairs)
# 
#   context: WorkerContext
#       immutable/frozen WorkerContext struct holding the worker's contextual information
#
#   logger: logging.Logger
#       object for logging messages
WorkerFunction = Callable[
    [Connection, Dict[str, str], WorkerContext, Logger],
    None
]

def worker(worker_function: WorkerFunction):
    command: str
    worker_id: UUID
    foreground: bool
    command, worker_id, foreground = parse_arguments()

    if foreground:
        start_worker = run
    else:
        start_worker = start_daemon

    # Init worker context
    context: WorkerContext = init_worker(worker_id, foreground)

    # Setup config
    config: Dict[str, str] = read_config_files(context)

    # Connect to PostgreSQL database
    connection: Connection = connect()

    # Register host
    register_host(connection, context.host_id, context.host_name)

    # Check if worker is already running
    existing_process_id: UUID
    existing_pid: int
    existing_process_id, existing_pid = get_existing_process_info(connection, context.host_id, context.worker_id)
    if existing_pid is None:
        already_running = False
    elif is_pid_alive(existing_pid):
        already_running = True
    else:
        print(f"Clean-up {context.worker_type} worker with ID {worker_id} and since it is no longer running.")
        delete_process(connection, existing_process_id)
        already_running = False

    # Handle command
    if command == 'start':
        if already_running:
            print(f"Cannot start {context.worker_type} worker with ID {worker_id} since it is already running with PID: {existing_pid}")
            sys.exit(1)
        print(f"Starting {context.worker_type} worker with ID {worker_id}.")
        start_worker(worker_function, connection, config, context)

    elif command == 'restart':
        if already_running:
            print(f"Restarting {context.worker_type} worker with ID {worker_id}.")
            stop_running_process(existing_pid)
        else:
            print(f"Starting {context.worker_type} worker with ID {worker_id} (it wasn't running).")
        start_worker(worker_function, connection, config, context)

    elif command == 'stop':
        if already_running:
            print(f"Stopping {context.worker_type} worker with ID {worker_id}.")
            stop_running_process(existing_pid)
        else:
            print(f"Cannot stop {context.worker_type} worker with ID {worker_id} since it is not running.")
            sys.exit(1)

    elif command == 'status':
        if already_running:
            print(f"Worker {context.worker_type} with ID {worker_id} is running with PID: {existing_pid}")
        else:
            print(f"Worker {context.worker_type} with ID {worker_id} is not running.")

    else:
        raise ValueError("Invalid command. Should have been caught by the argument parser!")

def start_daemon(worker_function: WorkerFunction,
                 connection: Connection,
                 config: Dict[str, str],
                 context: WorkerContext):
    # Disconnect since daemon will fork and child cannot share database
    # connection with parent.
    connection.close()
    connection = None
    with daemon.DaemonContext(working_directory=str(context.script_dir)):
        run(worker_function, connection, config, context)

def run(worker_function: WorkerFunction,
        connection: Connection,
        config: Dict[str, str],
        context: WorkerContext):
    if connection is None:
        connection = connect()
    logger: Logger = setup_logging(context)
    pid = os.getpid()
    try:
        logger.info(f"Started PID: {pid}")
        register_process(connection, context.process_id, context.worker_id, pid)
        while should_run(connection, context.process_id, context.foreground):
            worker_function(connection, config, context, logger)
            time.sleep(1)
    except Exception as e:
        tb = traceback.format_exc()
        error = f'{e}\n{tb}'
        logger.error(error)
    finally:
        logger.info(f"Stopped PID: {pid}")
        delete_process(connection, context.process_id)
        connection.close()

def should_run(connection: Connection, process_id: UUID, foreground: bool) -> bool:
    # Stop if termination has been requested, via the database
    if not keepalive(connection, process_id):
        return False

    # Stop if running in foreground and the parent process has died
    if foreground and not is_pid_alive(os.getppid()):
        return False 

    # Otherwise the process should continue running
    return True
