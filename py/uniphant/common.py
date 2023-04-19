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

class Worker:
    def connect_to_database(self):
        params = {"application_name": self.process_id}
        self.connection = psycopg2.connect(**params)
        self.connection.autocommit = True

    @staticmethod
    def is_pid_alive(pid):
        try:
            process = psutil.Process(pid)
            return process.is_running()
        except psutil.NoSuchProcess:
            return False

    def initialize_host_id(self):
        if not os.path.exists(self.host_id_file):
            with FileLock(self.lock_file):
                if not os.path.exists(self.host_id_file):
                    host_id = str(uuid.uuid4())
                    with open(self.host_id_file, "w") as f:
                        f.write(host_id)
        with open(self.host_id_file, "r") as f:
            self.host_id = f.read().strip()

    @staticmethod
    def is_valid_uuid(text):
        try:
            uuid.UUID(text)
            return True
        except ValueError:
            return False

    def setup_logging(self):
        log_dir = os.path.join(self.root_dir, "log", self.worker_type)
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)
        log_file = os.path.join(log_dir, self.worker_id + ".log")
        logger_name = self.worker_id + " " + self.worker_type
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
        if self.foreground:
            sh = logging.StreamHandler(sys.stdout)
            sh.setLevel(logging.INFO)
            sh.setFormatter(formatter)
            logger.addHandler(sh)
        self.logger = logger

    # Check if the process should continue running
    def alive(self):
        # Die if termination has been requested, via the database
        if not self.keepalive():
            return False

        # Die if termination has been requested, via a signal
        if self.termination_requested:
            return False

        # Background processes run forever until stopped
        if not self.foreground:
            return True

        # Foreground processes run until parent process dies
        if Worker.is_pid_alive(self.parent_pid):
            return True
        else:
            return False

    def run(self, worker_function):
        if self.connection is None:
            self.connect_to_database()
        self.setup_logging()
        try:
            with pidfile.TimeoutPIDLockFile(self.pid_file, acquire_timeout=1):
                self.logger.info("Started")
                self.register_process()
                while self.alive():
                    worker_function(self)
                    time.sleep(1)
        except LockTimeout:
            self.logger.error(f"PID file {self.pid_file} is already locked by another process.")
        except Exception as e:
            tb = traceback.format_exc()
            error = f'{e}\n{tb}'
            self.logger.error(error)
        finally:
            self.logger.info("Stopped")
            self.disconnect()

    def start_daemon(self, worker_function):
        # Disconnect since daemon will fork and child cannot share database
        # connection with parent.
        self.disconnect()
        with daemon.DaemonContext(
            working_directory=self.script_dir,
            umask=0o002,
        ):
            self.run(worker_function)

    def register_host(self):
        cursor = self.connection.cursor()
        cursor.execute("""
            SELECT register_host(%s,%s)
        """, (self.host_id, self.host_name))

    def register_process(self):
        self.connection.cursor().execute("""
            SELECT register_process(%s)
        """, (self.worker_id,))

    def keepalive(self):
        cursor = self.connection.cursor()
        cursor.execute("""
            SELECT keepalive()
        """)
        return cursor.fetchone()[0]

    def disconnect(self):
        cursor = self.connection.cursor()
        cursor.execute("""
            SELECT disconnect()
        """)
        self.connection.close()
        self.connection = None

    def signal_handler(self, sig, frame):
        self.termination_requested = True

    def get_pid_for_running_process(self):
        if not os.path.exists(self.pid_file):
            return None
        else:
            with open(self.pid_file) as f:
                pid = int(f.read())
                if Worker.is_pid_alive(pid):
                    return pid
                else:
                    os.remove(self.pid_file)
                    return None

    def stop_running_process(self):
        pid = self.get_pid_for_running_process()
        os.kill(pid, signal.SIGTERM)
        time.sleep(0.1)
        while self.get_pid_for_running_process() is not None:
            print(f"Waiting for pid {pid} to die.")
            time.sleep(1)

    @staticmethod
    def parse_key_value_format(conf_file):
        config_data = {}
        with open(conf_file, 'r') as file:
            for line in file:
                if line.strip() == '' or line.strip().startswith('#'):
                    continue
                key, value = line.strip().split('=', 1)
                config_data[key.strip()] = value.strip()
        return config_data

    def read_secret_config_files(self):
        user_home = os.path.expanduser("~")
        secrets_root = os.path.join(user_home, ".uniphant", "secrets")
        rel_path = os.path.relpath(self.script_dir, self.root_dir)
        self.secret_dir = os.path.join(secrets_root, rel_path)
        current_dir = self.script_dir
        relative_dirs = []
        while current_dir != self.root_dir:
            relative_dirs.append(os.path.relpath(current_dir, self.root_dir))
            current_dir = os.path.dirname(current_dir)
        for rel_dir in relative_dirs:
            secret_conf_file = os.path.join(secrets_root, rel_dir, 'secrets.conf')
            if os.path.exists(secret_conf_file):
                parsed_data = Worker.parse_key_value_format(secret_conf_file)
                for key, value in parsed_data.items():
                    if key in self.config:
                        raise ValueError(f"Duplicate self key: {key}")
                    self.config[key] = value

    def read_config_files(self):
        self.config = {}
        current_dir = self.script_dir
        directories = []
        while current_dir != self.root_dir:
            directories.append(current_dir)
            current_dir = os.path.dirname(current_dir)
        directories.append(self.root_dir)
        for directory in directories:
            conf_file = os.path.join(directory, "uniphant.conf")
            if os.path.exists(conf_file):
                parsed_data = Worker.parse_key_value_format(conf_file)
                for key, value in parsed_data.items():
                    if key in self.config:
                        raise ValueError(f"Duplicate self key: {key}")
                    self.config[key] = value

        # Read secret self files
        self.read_secret_config_files()

    @staticmethod
    def get_calling_file_path():
        frame = inspect.currentframe()
        while frame:
            frame_info = inspect.getframeinfo(frame)
            if frame_info.filename != __file__:
                return os.path.abspath(frame_info.filename)
            frame = frame.f_back
        raise RuntimeError("Failed to find the calling script's path.")

    @staticmethod
    def get_script_details():
        script_path = Worker.get_calling_file_path()
        script_dir = os.path.dirname(script_path)
        path_components = script_path.split(os.path.sep)
        workers_count = path_components.count("workers")
        if workers_count == 0:
            raise ValueError("The worker script must reside under 'workers'")
        elif workers_count > 1:
            raise ValueError("There should be only one 'workers' in the path")
        workers_index = path_components.index("workers")
        root_dir = os.path.join(os.path.sep, *path_components[:workers_index])
        worker_type_components = path_components[workers_index + 1:]
        worker_type = ".".join(worker_type_components).rstrip(".py")
        return root_dir, script_dir, worker_type

    def set_pid_file(self):
        pid_dir = os.path.join(self.root_dir, "pid", self.worker_type)
        if not os.path.exists(pid_dir):
            os.makedirs(pid_dir)
        self.pid_file = os.path.join(pid_dir, self.worker_id + ".pid")

    def init_vars(self):
        self.root_dir, self.script_dir, self.worker_type = Worker.get_script_details()
        self.lock_file = os.path.join(self.root_dir, ".lock")
        self.host_id_file = os.path.join(self.root_dir, ".host_id")
        self.initialize_host_id()
        self.process_id = str(uuid.uuid4())
        self.host_name = socket.gethostname()
        self.foreground = None # boolean, set by __init__
        self.worker_id = None # int, set by __init__
        self.parent_pid = None # int or None, set by __init__

    def __init__(self, worker_function):
        # Flag to indicate if a termination request has been received
        self.termination_requested = False
        # Setup signal handler
        signal.signal(signal.SIGTERM, self.signal_handler)

        # Init class variables
        self.init_vars()

        # Setup self.config
        self.read_config_files()

        # Parse arguments
        parser = argparse.ArgumentParser(description=self.worker_type)
        parser.add_argument('worker_id',
                            help='Worker ID')
        parser.add_argument('command',
                            nargs=1,
                            choices=["start", "restart", "stop", "status"],
                            help='Command to run')
        parser.add_argument('-f', '--foreground',
                            action='store_true',
                            default=self.foreground,
                            help='Run in the foreground')
        args = parser.parse_args()

        # Extract parsed arguments
        command = args.command[0]

        self.worker_id = args.worker_id
        if not Worker.is_valid_uuid(self.worker_id):
            print(f"The specified worker_id {self.worker_id} is not a valid UUID")
            parser.print_usage(sys.stderr)
            sys.exit(2)

        if args.foreground:
            self.foreground = True
            self.parent_pid = os.getppid()
            start_worker = self.run
            os.umask(0o002)
        else:
            self.foreground = False
            self.parent_pid = None
            start_worker = self.start_daemon

        # Connect to database
        self.connect_to_database()

        # Register host
        self.register_host()

        # PID file
        self.set_pid_file()
        pid = self.get_pid_for_running_process()
        is_running = pid is not None

        # Handle command
        if command == 'start':
            if is_running:
                print(f"Cannot start worker {self.worker_type} worker with id {self.worker_id} since it is already running with PID {pid}.")
                sys.exit(1)
            print(f"Starting worker {self.worker_type} with ID {self.worker_id}.")
            start_worker(worker_function)

        elif command == 'restart':
            if is_running:
                print(f"Restarting worker {self.worker_type} with ID {self.worker_id} and old PID {pid}.")
                self.stop_running_process()
            else:
                print(f"Starting worker {self.worker_type} with ID {self.worker_id} (it wasn't running)")
            start_worker(worker_function)

        elif command == 'stop':
            if is_running:
                print(f"Stopping worker {self.worker_type} with ID {self.worker_id} and PID {pid}.")
                self.stop_running_process()
            else:
                print(f"Cannot stop worker {self.worker_type} with ID {self.worker_id} since it is not running.")
                sys.exit(1)

        elif command == 'status':
            if is_running:
                print(f"Worker {self.worker_type} with ID {self.worker_id} is running with PID {pid}.")
            else:
                print(f"Worker {self.worker_type} with ID {self.worker_id} is not running.")

        else:
            parser.print_usage(sys.stderr)
            sys.exit(2)
