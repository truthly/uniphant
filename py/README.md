# Language Agnostic Uniphant System Implementation Manual

This manual provides a comprehensive and language-agnostic guide for implementing a compatible port of the Uniphant system code. The Uniphant system is a design pattern that employs a hierarchical directory structure for key-value configuration files and uses a PostgreSQL database to maintain the state of all components. This manual assumes that you have a solid understanding of programming concepts and familiarity with the target programming language.

The Uniphant system is designed to streamline the development and deployment of background processes in various applications. Its modular and easily configurable architecture allows developers to incorporate background processes into their applications seamlessly. The system focuses on three core principles: modularity, configurability, and reliability.

Modularity is achieved through a hierarchical directory structure, which enables the efficient organization and separation of configuration files. This structure facilitates the management of multiple worker processes and ensures a clean and well-organized system.

Configurability is provided through key-value configuration files that offer a simple yet powerful way to manage worker processes. These files are arranged in a hierarchical manner, making it easy to apply configurations at different levels of granularity. Additionally, command-line arguments are used to offer further flexibility in managing worker processes.

Reliability is ensured by utilizing a PostgreSQL database to maintain the state of all components, including worker processes and host registration. This approach provides a robust and stable environment for the worker processes to operate in while ensuring data integrity and proper management of resources.

In summary, this manual aims to equip you with the necessary knowledge and understanding to implement a compatible port of the Uniphant system code. By following the principles and design patterns presented in this guide, you will be able to create a versatile and efficient solution for managing and deploying background processes in various applications.

**Table of Contents:**

- [Language Agnostic Uniphant System Implementation Manual](#language-agnostic-uniphant-system-implementation-manual)
  - [1. Overview](#1-overview)
  - [2. Required Libraries and Dependencies](#2-required-libraries-and-dependencies)
  - [3. Core Functions](#3-core-functions)
  - [4. Configuration Management](#4-configuration-management)
    - [4.1. Reading Configuration Files](#41-reading-configuration-files)
    - [4.2. Configuration File Format](#42-configuration-file-format)
    - [4.3. Configuration Dictionary](#43-configuration-dictionary)
  - [5. Signal Handling](#5-signal-handling)
  - [6. Process Management](#6-process-management)
  - [7. Logging](#7-logging)
  - [8. Main Function](#8-main-function)
  - [9. Worker Function](#9-worker-function)
  - [10. Database Connection Management](#10-database-connection-management)

## 1. Overview

The Uniphant system consists of the following components:

   - PostgreSQL database connection management
   - Configuration file parsing and management
   - Process management, including starting, stopping, and monitoring
   - Logging setup and management

## 2. Required Libraries and Dependencies

To implement the Uniphant system in another programming language, you will need to import or implement libraries that provide the following functionalities:

   - PostgreSQL database connection and interaction
   - Daemon and process management
   - File I/O and file locking
   - UUID generation
   - Logging
   - Signal handling
   - Command line argument parsing

## 3. Core Functions

The following core functions must be implemented:

   - `connect_to_database(config)`: Establishes a connection to the PostgreSQL database using the configuration provided.
   - `is_parent_alive(parent_pid)`: Checks if the parent process is still running.
   - `get_or_create_host_id(lock_file, host_id_file)`: Returns the host ID, either by reading it from the existing host ID file or by generating a new UUID and storing it in the host ID file.
   - `is_valid_uuid(text)`: Validates if the given text is a valid UUID.
   - `setup_logging(config)`: Sets up logging with the specified configuration.
   - `alive(config, connection)`: Determines if the process should continue running based on various conditions.
   - `run(config, connection, worker_function, pid_file)`: Runs the main loop, executing the worker_function with the provided configuration and connection.
   - `start_daemon(config, connection, worker_function, pid_file)`: Starts the process as a daemon with the provided configuration and connection.
   - `register_host(config, connection)`: Registers the host in the PostgreSQL database.
   - `register_process(config, connection)`: Registers the process in the PostgreSQL database.
   - `keepalive(connection)`: Checks if the process should continue running by querying the PostgreSQL database.
   - `disconnect(connection)`: Disconnects from the PostgreSQL database.
   - `signal_handler(sig, frame)`: Handles termination signals and sets a global `termination_requested` flag.
   - `is_pid_alive(pid)`: Checks if the process with the given PID is still running.
   - `get_pid_for_running_process(pid_file)`: Returns the PID of the running process if the PID file exists and the process is running.
   - `stop_running_process(pid_file)`: Stops the running process by sending a termination signal and waiting for the process to terminate.
   - `parse_key_value_format(conf_file)`: Parses a configuration file in key-value format and returns a dictionary of the parsed data.
   - `read_secret_config_files(config)`: Reads and parses secret configuration files from the user's home directory.
   - `read_config_files(config)`: Reads and parses configuration files, including secret configuration files.
   - `get_calling_file_path()`: Returns the absolute path of the calling script.
   - `get_script_details()`: Returns the root directory, script directory, and worker type of the calling script.
   - `get_pid_file_path(config)`: Returns the PID file path based on the given configuration.
   - `setup_config()`: Sets up the initial configuration.
   - `main(worker_function)`: The main function that handles command line arguments and starts the appropriate process.

## 4. Configuration Management

The Uniphant system relies on a hierarchical directory structure for managing its configuration files. The configuration files are named `uniphant.conf` and are stored in various directories within the project. Additionally, secret configuration files, named `secrets.conf`, are stored in the `~/.uniphant/secrets` directory.

### 4.1. Reading Configuration Files

1. Traverse the directory hierarchy starting from the script's directory and moving towards the root directory of the project.
2. For each directory encountered, check if there is a `uniphant.conf` file.
3. If a `uniphant.conf` file exists, parse the file line by line, skipping empty lines or lines starting with `#`.
4. For non-empty lines, split the line at the first `=` character to obtain a key-value pair.
5. Store the key-value pair in a configuration dictionary. If a key already exists in the dictionary, raise a `ValueError` to indicate duplicate keys.
6. Repeat steps 2-5 for the secret configuration files located in the `~/.uniphant/secrets` directory.

### 4.2. Configuration File Format

The configuration files use a simple key-value format. Each line contains a key and a value separated by an equal sign `=`. Empty lines or lines starting with the hash symbol `#` are ignored. Example:

```
key1=value1
key2=value2
# This is a comment
key3=value3
```

### 4.3. Configuration Dictionary

The configuration dictionary is a data structure that stores the parsed configuration data. It is used throughout the system to provide access to configuration settings. The initial configuration dictionary should contain the following keys:

- `root_dir`: The root directory of the project.
- `script_dir`: The directory containing the script.
- `worker_type`: The type of the worker, derived from the script's file path.
- `lock_file`: The path to the lock file used for creating or accessing the host ID.
- `host_id_file`: The path to the file containing the host ID.
- `host_id`: The host ID, which is a UUID.
- `process_id`: A UUID representing the process ID.
- `host_name`: The hostname of the machine running the process.
- `foreground`: A boolean indicating whether the process should run in the foreground. Initially set to `None`.
- `worker_id`: A UUID representing the worker ID. Initially set to `None`.
- `parent_pid`: The parent process ID. Initially set to `None`.

These keys will be populated as the configuration files are read and parsed. Some keys, like `foreground`, `worker_id`, and `parent_pid`, will be updated later in the `main()` function, based on command-line arguments and other factors.

## 5. Signal Handling

The implementation should support handling signals for graceful termination. When a termination signal is received, the system should set a global flag, indicating that the termination has been requested.

## 6. Process Management

The system should include functions to manage processes, such as starting, stopping, and checking the status of processes. It should support running processes in the foreground or as a daemon, depending on the configuration. Additionally, the system should be able to determine if a parent process is still alive and running.

## 7. Logging

The Uniphant system should have a robust logging mechanism. It should allow setting different log levels and support logging to files and standard output (stdout). The log files should be stored in a dedicated 'log' directory, organized by worker type.

## 8. Main Function

The main function of the implementation should:

1. Set up the signal handler for termination signals.
2. Set up the configuration by reading and merging the key-value configuration files.
3. Parse command-line arguments, such as worker_id and command (start, restart, stop, or status).
4. Connect to the database and register the host.
5. Handle the command (start, restart, stop, or status) based on the provided command-line arguments.
6. If starting or restarting a process, start the worker function either in the foreground or as a daemon, depending on the configuration.

## 9. Worker Function

The worker function should be provided by the user and should contain the main logic of the process. The Uniphant system should continuously execute the worker function as long as the process is alive, as determined by the 'alive' function described in step 3.

## 10. Database Connection Management

1. Create a function called `connect_to_database` that takes a configuration dictionary as input and returns a database connection. The function should:
   - Connect to the PostgreSQL database using the parameters from the configuration dictionary.
   - Set the connection's `autocommit` property to `True`.

2. Create a function called `disconnect` that takes a database connection as input and:
   - Executes a `disconnect()` function in the database.
   - Closes the database connection.
