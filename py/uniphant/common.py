import psycopg2
import daemon
from daemon import pidfile
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

def get_or_create_host_id(config):
    host_id_file = config["host_id_file"]
    lock_file = config["lock_file"]

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

def get_worker_ids(config, connection):
    cursor = connection.cursor()
    cursor.execute("""
        SELECT get_worker_ids(%s, %s)
    """, (config["host_id"], config["worker_type"]))
    worker_ids = [result[0] for result in cursor.fetchall()]
    return worker_ids

def get_or_create_worker_id(config, connection):
    cursor = connection.cursor()
    cursor.execute("""
        SELECT get_or_create_worker_id(%s, %s)
    """, (config["host_id"], config["worker_type"]))
    worker_id = cursor.fetchone()[0]
    return worker_id

def setup_logging(config):
    logger = logging.getLogger(config["worker_id"] + " " + config["worker_type"])
    logger.setLevel(logging.INFO)

    # File handler
    fh = logging.FileHandler(config["log_file"])
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

def alive(config):
    # Background processes run forever until stopped
    if not config["foreground"]:
        return True

    # Foreground processes run until parent process dies
    if is_parent_alive(config["parent_pid"]):
        return True
    else:
        return False

def run(config, worker_function, pid_lock):
    with pid_lock:
        connection = connect_to_database(config)
        logger = setup_logging(config)
        try:
            logger.info("Started")
            while alive(config):
                keepalive(config, connection)
                worker_function(config, logger, connection)
                time.sleep(1)

        except Exception as e:
            tb = traceback.format_exc()
            error = f'{e}\n{tb}'
            logger.error(error)
        finally:
            logger.info("Stopped")
            disconnect(config, connection)
            if os.path.exists(config["pid_file"]):
                os.remove(config["pid_file"])
            os.kill(os.getpid(), signal.SIGTERM)

def start_daemon(config, worker_function, pid_lock):
    with daemon.DaemonContext(
        working_directory=config["script_dir"],
        umask=0o002,
    ):
        run(config, worker_function, pid_lock)

def register_host(config, connection):
    host_id = config["host_id"]
    host_name = config["host_name"]

    cursor = connection.cursor()
    cursor.execute("""
        SELECT register_host(%s,%s)
    """, (host_id, host_name))

def keepalive(config, connection):
    host_id = config["host_id"]
    host_name = config["host_name"]
    worker_id = config["worker_id"]
    worker_type = config["worker_type"]

    cursor = connection.cursor()
    cursor.execute("""
        SELECT keepalive(%s,%s,%s,%s)
    """, (host_id, host_name, worker_id, worker_type))

def disconnect(config, connection):
    cursor = connection.cursor()
    cursor.execute("""
        SELECT disconnect()
    """)

    connection.close()

def is_pid_alive(pid):
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True

def get_pid_for_running_process(config):
    if not "pid_file" in config:
        raise ValueError('No pid_file in config')

    pid_file = config["pid_file"]

    if pid_file is None:
        raise ValueError('pid_file in config is None')

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

def stop_running_process(config):
    pid = get_pid_for_running_process(config)
    os.kill(pid, signal.SIGTERM)
    time.sleep(0.1)
    while get_pid_for_running_process(config) is not None:
        print(f"Waiting for pid {pid} to die.")
        time.sleep(1)

def parse_key_value_format(file_path):
    config_data = {}
    with open(file_path, 'r') as file:
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

def main(worker_function):
    calling_file_path = (
        inspect.getframeinfo(inspect.currentframe().f_back).filename
    )
    script_path = os.path.abspath(calling_file_path)
    script_dir = os.path.dirname(script_path)

    path_components = script_path.split(os.path.sep)
    if "api_integrations" not in path_components:
        raise ValueError("The worker script must reside under 'api_integrations'")

    api_integrations_index = path_components.index("api_integrations")
    root_dir = os.path.join(os.path.sep, *path_components[:api_integrations_index])
    worker_type_components = path_components[api_integrations_index + 1:]
    worker_type = ".".join(worker_type_components).rstrip(".py")

    config = {
        "root_dir": root_dir,
        "script_dir": script_dir,
        "worker_type": worker_type,
        "pid_dir": os.path.join(root_dir, "pid", worker_type),
        "log_dir": os.path.join(root_dir, "log", worker_type),
        "host_id_file": os.path.join(root_dir, ".host_id"),
        "lock_file": os.path.join(root_dir, ".lock"),
        "foreground": False
    }

    read_config_files(config)

    parser = argparse.ArgumentParser(description=worker_type)

    parser.add_argument('command',
                        nargs='?',
                        choices=['start', 'stop', 'restart', 'status'],
                        help='Command to run')

    parser.add_argument('worker_id',
                        nargs='?',
                        default=None,
                        help='Worker ID')

    parser.add_argument('-f', '--foreground',
                        action='store_true',
                        default=config["foreground"],
                        help='Run in the foreground')

    args = parser.parse_args()

    os.umask(0o002)

    config["foreground"] = args.foreground

    config["process_id"] = str(uuid.uuid4())
    config["host_id"] = get_or_create_host_id(config)
    config["host_name"] = socket.gethostname()

    connection = connect_to_database(config)

    register_host(config, connection)

    # The worker_id is optional in case only one worker should run,
    # in which case the worker_id will be generated, and reused on
    # the next invocation.
    worker_id = args.worker_id
    if worker_id is None:
        worker_id = get_or_create_worker_id(config, connection)
    elif not is_valid_uuid(worker_id):
        raise ValueError(f"The specified worker_id {worker_id} is not a valid UUID")
    config["worker_id"] = worker_id

    if not os.path.exists(config["pid_dir"]):
        os.makedirs(config["pid_dir"])

    if not os.path.exists(config["log_dir"]):
        os.makedirs(config["log_dir"])

    config["pid_file"] = os.path.join(config["pid_dir"], f"{worker_id}.pid")
    config["log_file"] = os.path.join(config["log_dir"], f"{worker_id}.log")


    pid = get_pid_for_running_process(config)
    is_running = pid is not None

    command = args.command

    if config["foreground"]:
        config["parent_pid"] = os.getppid()
        # Foreground implies `start` command, if not specified
        if command is None:
            command = 'start'
        start_worker = run
    else:
        start_worker = start_daemon

    disconnect(config, connection)
    connection = None

    if command == 'start':
        if is_running:
            print(f"Cannot start worker {worker_type} worker with id {worker_id} since it is already running with PID {pid}.")
            sys.exit(1)

        print(f"Starting worker {worker_type} with ID {worker_id}.")

        pid_lock = pidfile.TimeoutPIDLockFile(config["pid_file"])
        start_worker(config, worker_function, pid_lock)

    elif command == 'restart':
        if is_running:
            print(f"Restarting worker {worker_type} with ID {worker_id} and old PID {pid}.")
            stop_running_process(config)
        else:
            print(f"Starting worker {worker_type} with ID {worker_id} (it wasn't running)")

        pid_lock = pidfile.TimeoutPIDLockFile(config["pid_file"])
        start_worker(config, worker_function, pid_lock)

    elif command == 'stop':
        if is_running:
            print(f"Stopping worker {worker_type} with ID {worker_id} and PID {pid}.")
            stop_running_process(config)
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
