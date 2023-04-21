import psycopg2
import daemon
from daemon import pidfile
from lockfile import LockTimeout
import logging
import traceback
import time
import os
import argparse
import sys
import signal
import uuid
import signal
from .init_worker import init_worker
from .read_config_files import read_config_files

# Flag to indicate if a termination request has been received
termination_requested = False

def connect_to_database(process_id):
    params = {"application_name": process_id}
    connection = psycopg2.connect(**params)
    connection.autocommit = True
    return connection

def is_valid_uuid(text):
    try:
        uuid.UUID(text)
        return True
    except ValueError:
        return False

def setup_logging(state):
    log_dir = os.path.join(state.root_dir, "log", state.worker_type)
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    log_file = os.path.join(log_dir, state.worker_id + ".log")
    logger_name = state.worker_id + " " + state.worker_type
    logger = logging.getLogger(logger_name)
    logger.setLevel(logging.INFO)
    # File handler
    fh = logging.FileHandler(log_file)
    fh.setLevel(logging.INFO)
    formatstr = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    formatter = logging.Formatter(formatstr)
    fh.setFormatter(formatter)
    logger.addHandler(fh)
    # Stream handler
    if state.foreground:
        sh = logging.StreamHandler(sys.stdout)
        sh.setLevel(logging.INFO)
        sh.setFormatter(formatter)
        logger.addHandler(sh)
    return logger

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
        disconnect(connection)

def start_daemon(worker_function, connection, config, state):
    # Disconnect since daemon will fork and child cannot share database
    # connection with parent.
    disconnect(connection)
    connection = None
    with daemon.DaemonContext(working_directory=state.script_dir):
        run(worker_function, connection, config, state)

def register_host(connection, host_id, host_name):
    connection.cursor().execute("""
        SELECT register_host(%s,%s)
    """, (host_id, host_name))

def register_process(connection, worker_id):
    connection.cursor().execute("""
        SELECT register_process(%s)
    """, (worker_id,))

def keepalive(connection):
    cursor = connection.cursor()
    cursor.execute("""
        SELECT keepalive()
    """)
    return cursor.fetchone()[0]

def disconnect(connection):
    connection.cursor().execute("""
        SELECT disconnect()
    """)
    connection.close()

def signal_handler(sig, frame):
    global termination_requested
    termination_requested = True

def is_pid_alive(pid):
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True

def get_pid_for_running_process(pid_file):
    if not os.path.exists(pid_file):
        return None
    else:
        with open(pid_file) as f:
            pid = int(f.read())
            if is_pid_alive(pid):
                return pid
            else:
                os.remove(pid_file)
                return None

def stop_running_process(pid_file):
    pid = get_pid_for_running_process(pid_file)
    os.kill(pid, signal.SIGTERM)
    time.sleep(0.2)
    while get_pid_for_running_process(pid_file) is not None:
        print(f"Waiting for pid {pid} to die.")
        time.sleep(1)

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
