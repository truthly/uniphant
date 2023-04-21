import psycopg2
import daemon
from daemon import pidfile
from lockfile import LockTimeout
import traceback
import time
import os
import argparse
import sys
import signal
import uuid
import signal
from .init_worker import init_worker
from .setup_logging import setup_logging
from .read_config_files import read_config_files
from .database_functions import connect_to_database, disconnect_from_database, keepalive, register_process, register_host
from .utils import is_pid_alive, is_valid_uuid, get_pid_for_running_process, stop_running_process

# Flag to indicate if a termination request has been received
termination_requested = False

def signal_handler(sig, frame):
    global termination_requested
    termination_requested = True

# Check if the process should continue running
def alive(connection, foreground):
    # Die if termination has been requested, via the database
    if not keepalive(connection):
        return False

    # Die if termination has been requested, via a signal
    if termination_requested:
        return False

    # Background processes run forever until stopped
    if not foreground:
        return True

    # Foreground processes run until parent process dies
    if is_pid_alive(os.getppid()):
        return True
    else:
        return False 

def run(worker_function, connection, config, state):
    if connection is None:
        connection = connect_to_database(state.process_id)
    logger = setup_logging(state)
    try:
        with pidfile.TimeoutPIDLockFile(state.pid_file, acquire_timeout=1):
            logger.info("Started")
            register_process(connection, state.worker_id)
            while alive(connection, state.foreground):
                worker_function(connection, config, state, logger)
                time.sleep(1)
    except LockTimeout:
        logger.error(f"PID file {state.pid_file} is already locked by another process.")
    except Exception as e:
        tb = traceback.format_exc()
        error = f'{e}\n{tb}'
        logger.error(error)
    finally:
        logger.info("Stopped")
        disconnect_from_database(connection)

def start_daemon(worker_function, connection, config, state):
    # Disconnect since daemon will fork and child cannot share database
    # connection with parent.
    disconnect_from_database(connection)
    connection = None
    with daemon.DaemonContext(working_directory=str(state.script_dir)):
        run(worker_function, connection, config, state)

def worker(worker_function):
    # Setup signal handler
    signal.signal(signal.SIGTERM, signal_handler)

    # Set umask to 0o077 to restrict access to the owner (current user) only
    os.umask(0o077)

    # Parse arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('worker_id',
                        help='Worker ID')
    parser.add_argument('command',
                        nargs=1,
                        choices=["start", "restart", "stop", "status"],
                        help='Command to run')
    parser.add_argument('-f', '--foreground',
                        action='store_true',
                        default=False,
                        help='Run in the foreground')
    args = parser.parse_args()

    # Extract parsed arguments
    command = args.command[0]
    worker_id = args.worker_id
    foreground = args.foreground

    if not is_valid_uuid(worker_id):
        print(f"The specified worker_id {worker_id} is not a valid UUID")
        parser.print_usage(sys.stderr)
        sys.exit(2)

    if foreground:
        start_worker = run
    else:
        start_worker = start_daemon

    # Init worker state
    state = init_worker(worker_id, foreground)

    # Setup config
    config = read_config_files(state)

    # Set parser description to worker type
    parser.description = state.worker_type

    # Connect to database
    connection = connect_to_database(state.process_id)

    # Register host
    register_host(connection, state.host_id, state.host_name)

    # Check if worker is already running
    pid = get_pid_for_running_process(state.pid_file)
    is_running = pid is not None

    # Handle command
    if command == 'start':
        if is_running:
            print(f"Cannot start worker {state.worker_type} worker with id {worker_id} since it is already running with PID {pid}.")
            sys.exit(1)
        print(f"Starting worker {state.worker_type} with ID {worker_id}.")
        start_worker(worker_function, connection, config, state)

    elif command == 'restart':
        if is_running:
            print(f"Restarting worker {state.worker_type} with ID {worker_id} and old PID {pid}.")
            stop_running_process(state.pid_file)
        else:
            print(f"Starting worker {state.worker_type} with ID {worker_id} (it wasn't running)")
        start_worker(worker_function, connection, config, state)

    elif command == 'stop':
        if is_running:
            print(f"Stopping worker {state.worker_type} with ID {worker_id} and PID {pid}.")
            stop_running_process(state.pid_file)
        else:
            print(f"Cannot stop worker {state.worker_type} with ID {worker_id} since it is not running.")
            sys.exit(1)

    elif command == 'status':
        if is_running:
            print(f"Worker {state.worker_type} with ID {worker_id} is running with PID {pid}.")
        else:
            print(f"Worker {state.worker_type} with ID {worker_id} is not running.")

    else:
        parser.print_usage(sys.stderr)
        sys.exit(2)
