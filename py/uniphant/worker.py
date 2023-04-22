# Standard library imports
import os
import sys
import time
import traceback
from types import FrameType
from typing import Callable, Dict, Set
from uuid import UUID

# Related third-party imports
import daemon
from daemon import pidfile
from lockfile import LockTimeout
from psycopg2.extensions import connection as Connection
from logging import Logger
import signal

# Local application/library-specific imports
from .worker_context import WorkerContext
from .init_worker import init_worker
from .setup_logging import setup_logging
from .read_config_files import read_config_files
from .parse_arguments import parse_arguments
from .database import connect, disconnect, keepalive, register_process, register_host
from .utils import is_pid_alive, get_pid_for_running_process, stop_running_process

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
#
#   signals: Set[int]
#       set containing received signals
WorkerFunction = Callable[
    [Connection, Dict[str, str], WorkerContext, Logger, Set[int]],
    None
]

def worker(worker_function: WorkerFunction):
    # Setup signal handler
    signals: Set[int] = set()
    signal.signal(signal.SIGTERM, lambda sig, frame: signal_handler(sig, frame, signals))

    # Set umask to 0o077 to restrict access to the owner (current user) only
    os.umask(0o077)

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
    connection: Connection = connect(context.process_id)

    # Register host
    register_host(connection, context.host_id, context.host_name)

    # Check if worker is already running
    cur_pid: int = get_pid_for_running_process(context.pid_file)
    already_running = cur_pid is not None

    # Handle command
    if command == 'start':
        if already_running:
            print(f"Cannot start {context.worker_type} worker with ID {worker_id} since it is already running with PID: {cur_pid}")
            sys.exit(1)
        print(f"Starting {context.worker_type} worker with ID {worker_id}.")
        start_worker(worker_function, connection, config, context, signals)

    elif command == 'restart':
        if already_running:
            print(f"Restarting {context.worker_type} worker with ID {worker_id}.")
            stop_running_process(context.pid_file)
        else:
            print(f"Starting {context.worker_type} worker with ID {worker_id} (it wasn't running).")
        start_worker(worker_function, connection, config, context, signals)

    elif command == 'stop':
        if already_running:
            print(f"Stopping {context.worker_type} worker with ID {worker_id}.")
            stop_running_process(context.pid_file)
        else:
            print(f"Cannot stop {context.worker_type} worker with ID {worker_id} since it is not running.")
            sys.exit(1)

    elif command == 'status':
        if already_running:
            print(f"Worker {context.worker_type} with ID {worker_id} is running with PID: {cur_pid}")
        else:
            print(f"Worker {context.worker_type} with ID {worker_id} is not running.")

    else:
        raise ValueError("Invalid command. Should have been caught by the argument parser!")

def start_daemon(worker_function: WorkerFunction,
                 connection: Connection,
                 config: Dict[str, str],
                 context: WorkerContext,
                 signals: Set[int]):
    # Disconnect since daemon will fork and child cannot share database
    # connection with parent.
    disconnect(connection)
    connection = None
    with daemon.DaemonContext(working_directory=str(context.script_dir)):
        run(worker_function, connection, config, context, signals)

def run(worker_function: WorkerFunction,
        connection: Connection,
        config: Dict[str, str],
        context: WorkerContext,
        signals: Set[int]):
    if connection is None:
        connection = connect(context.process_id)
    logger: Logger = setup_logging(context)
    try:
        with pidfile.TimeoutPIDLockFile(context.pid_file, acquire_timeout=1):
            logger.info("Started PID: " + str(os.getpid()))
            register_process(connection, context.worker_id)
            while should_run(connection, context.foreground, signals):
                worker_function(connection, config, context, logger, signals)
                time.sleep(1)
    except LockTimeout:
        logger.error(f"PID file {context.pid_file} is already locked by another process.")
    except Exception as e:
        tb = traceback.format_exc()
        error = f'{e}\n{tb}'
        logger.error(error)
    finally:
        logger.info("Stopped PID: " + str(os.getpid()))
        disconnect(connection)

def should_run(connection: Connection, foreground: bool, signals: Set[int]) -> bool:
    # Stop if termination has been requested, via the database
    if not keepalive(connection):
        return False

    # Stop if termination has been requested, via a TERM signal (signal 15)
    if signal.SIGTERM in signals:
        return False

    # Stop if running in foreground and the parent process has died
    if foreground and not is_pid_alive(os.getppid()):
        return False 

    # Otherwise the process should continue running
    return True

def signal_handler(sig: int, frame: FrameType, signals: Set[int]):
    signals.add(sig)
