import psycopg2
import daemon
from daemon import pidfile
from lockfile import LockTimeout
import logging
import traceback
import time
import os
import argparse
import inspect
import sys
import signal
import psutil
import uuid
from filelock import FileLock
import socket
import signal

termination_requested = False

def connect_to_database(config):
    params = {"application_name": config["process_id"]}
    connection = psycopg2.connect(**params)
    connection.autocommit = True
    return connection

def is_parent_alive(parent_pid):
    try:
        parent = psutil.Process(parent_pid)
        return parent.is_running()
    except psutil.NoSuchProcess:
        return False

def get_or_create_host_id(lock_file, host_id_file):
    if not os.path.exists(host_id_file):
        with FileLock(lock_file):
            if not os.path.exists(host_id_file):
                host_id = str(uuid.uuid4())
                with open(host_id_file, "w") as f:
                    f.write(host_id)
                return host_id
    with FileLock(lock_file):
        with open(host_id_file, "r") as f:
            host_id = f.read()
    return host_id

def is_valid_uuid(text):
    try:
        uuid.UUID(text)
        return True
    except ValueError:
        return False

def setup_logging(config):
    log_dir = os.path.join(config["root_dir"], "log", config["worker_type"])
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    log_file = os.path.join(log_dir, config["worker_id"] + ".log")
    logger_name = config["worker_id"] + " " + config["worker_type"]
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
    if config["foreground"]:
        sh = logging.StreamHandler(sys.stdout)
        sh.setLevel(logging.INFO)
        sh.setFormatter(formatter)
        logger.addHandler(sh)
    return logger

def alive(config, connection):
    # Die if termination has been requested, via the database
    if not keepalive(connection):
        return False
    # Die if termination has been requested, via a signal
    if termination_requested:
        return False
    # Background processes run forever until stopped
    if not config["foreground"]:
        return True
    # Foreground processes run until parent process dies
    if is_parent_alive(config["parent_pid"]):
        return True
    else:
        return False

def run(config, connection, worker_function, pid_file):
    if connection is None:
        connection = connect_to_database(config)
    logger = setup_logging(config)
    try:
        with pidfile.TimeoutPIDLockFile(pid_file, acquire_timeout=1):
            logger.info("Started")
            register_process(config, connection)
            while alive(config, connection):
                worker_function(config, logger, connection)
                time.sleep(1)
    except LockTimeout:
        logger.error(f"PID file {pid_file} is already locked by another process.")
    except Exception as e:
        tb = traceback.format_exc()
        error = f'{e}\n{tb}'
        logger.error(error)
    finally:
        logger.info("Stopped")
        disconnect(connection)

def start_daemon(config, connection, worker_function, pid_file):
    # Disconnect since daemon will fork and child cannot share database
    # connection with parent.
    disconnect(connection)
    connection = None
    with daemon.DaemonContext(
        working_directory=config["script_dir"],
        umask=0o002,
    ):
        run(config, connection, worker_function, pid_file)

def register_host(config, connection):
    host_id = config["host_id"]
    host_name = config["host_name"]
    cursor = connection.cursor()
    cursor.execute("""
        SELECT register_host(%s,%s)
    """, (host_id, host_name))

def register_process(config, connection):
    worker_id = config["worker_id"]
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
    cursor = connection.cursor()
    cursor.execute("""
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
    time.sleep(0.1)
    while get_pid_for_running_process(pid_file) is not None:
        print(f"Waiting for pid {pid} to die.")
        time.sleep(1)

def parse_key_value_format(conf_file):
    config_data = {}
    with open(conf_file, 'r') as file:
        for line in file:
            if line.strip() == '' or line.strip().startswith('#'):
                continue
            key, value = line.strip().split('=', 1)
            config_data[key.strip()] = value.strip()
    return config_data

def read_config_files(config):
    current_dir = config["script_dir"]
    root_dir = config["root_dir"]
    directories = []
    while current_dir != root_dir:
        directories.append(current_dir)
        current_dir = os.path.dirname(current_dir)
    directories.append(root_dir)
    for directory in directories:
        conf_file = os.path.join(directory, "uniphant.conf")
        if os.path.exists(conf_file):
            parsed_data = parse_key_value_format(conf_file)
            for key, value in parsed_data.items():
                if key in config:
                    raise ValueError(f"Duplicate config key: {key}")
                config[key] = value

def get_calling_file_path():
    frame = inspect.currentframe()
    while frame:
        frame_info = inspect.getframeinfo(frame)
        if frame_info.filename != __file__:
            return os.path.abspath(frame_info.filename)
        frame = frame.f_back
    raise RuntimeError("Failed to find the calling script's path.")

def get_script_details():
    script_path = get_calling_file_path()
    script_dir = os.path.dirname(script_path)
    path_components = script_path.split(os.path.sep)
    if "api_integrations" not in path_components:
        raise ValueError("The worker script must reside under 'api_integrations'")
    api_integrations_index = path_components.index("api_integrations")
    root_dir = os.path.join(os.path.sep, *path_components[:api_integrations_index])
    worker_type_components = path_components[api_integrations_index + 1:]
    worker_type = ".".join(worker_type_components).rstrip(".py")
    return root_dir, script_dir, worker_type

def setup_config():
    root_dir, script_dir, worker_type = get_script_details()
    lock_file = os.path.join(root_dir, ".lock")
    host_id_file = os.path.join(root_dir, ".host_id")
    host_id = get_or_create_host_id(lock_file, host_id_file)
    config = {
        "root_dir": root_dir,
        "script_dir": script_dir,
        "worker_type": worker_type,
        "lock_file": lock_file,
        "host_id_file": host_id_file,
        "host_id": host_id,
        "process_id": str(uuid.uuid4()),
        "host_name": socket.gethostname(),
        # Reserve config keys to be assigned in main(), preventing accidental
        # overrides if used in config files, ensuring error is raised.
        "foreground": None,
        "worker_id": None,
        "parent_pid": None
    }
    read_config_files(config)
    return config

def main(worker_function):
    signal.signal(signal.SIGTERM, signal_handler)
    config = setup_config()
    worker_type = config["worker_type"]
    parser = argparse.ArgumentParser(description=worker_type)
    parser.add_argument('worker_id',
                        help='Worker ID')
    parser.add_argument('command',
                        nargs=1,
                        choices=["start", "restart", "stop", "status"],
                        help='Command to run')
    parser.add_argument('-f', '--foreground',
                        action='store_true',
                        default=config["foreground"],
                        help='Run in the foreground')
    args = parser.parse_args()
    os.umask(0o002)
    config["foreground"] = args.foreground
    connection = connect_to_database(config)
    register_host(config, connection)
    command = args.command[0]
    worker_id = args.worker_id
    if not is_valid_uuid(worker_id):
        print(f"The specified worker_id {worker_id} is not a valid UUID")
        parser.print_usage(sys.stderr)
        sys.exit(2)
    config["worker_id"] = worker_id
    pid_dir = os.path.join(config["root_dir"], "pid", worker_type)
    if not os.path.exists(pid_dir):
        os.makedirs(pid_dir)
    pid_file = os.path.join(pid_dir, worker_id + ".pid")
    pid = get_pid_for_running_process(pid_file)
    is_running = pid is not None
    if config["foreground"]:
        config["parent_pid"] = os.getppid()
        start_worker = run
    else:
        start_worker = start_daemon
    if command == 'start':
        if is_running:
            print(f"Cannot start worker {worker_type} worker with id {worker_id} since it is already running with PID {pid}.")
            sys.exit(1)
        print(f"Starting worker {worker_type} with ID {worker_id}.")
        start_worker(config, connection, worker_function, pid_file)
    elif command == 'restart':
        if is_running:
            print(f"Restarting worker {worker_type} with ID {worker_id} and old PID {pid}.")
            stop_running_process(pid_file)
        else:
            print(f"Starting worker {worker_type} with ID {worker_id} (it wasn't running)")
        start_worker(config, connection, worker_function, pid_file)
    elif command == 'stop':
        if is_running:
            print(f"Stopping worker {worker_type} with ID {worker_id} and PID {pid}.")
            stop_running_process(pid_file)
        else:
            print(f"Cannot stop worker {worker_type} with ID {worker_id} since it is not running.")
            sys.exit(1)
    elif command == 'status':
        if is_running:
            print(f"Worker {worker_type} with ID {worker_id} is running with PID {pid}.")
        else:
            print(f"Worker {worker_type} with ID {worker_id} is not running.")
    else:
        parser.print_usage(sys.stderr)
        sys.exit(2)
