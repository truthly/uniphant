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
    - [4.4. Function to Configuration Key Mapping](#44-function-to-configuration-key-mapping)
  - [5. Signal Handling](#5-signal-handling)
  - [6. Process Management](#6-process-management)
  - [7. Logging](#7-logging)
  - [8. Main Function](#8-main-function)
  - [9. Worker Function](#9-worker-function)
  - [10. Database Connection Management](#10-database-connection-management)
    - [10.1. Database API Functions for Host and Process Management](#101-database-api-functions-for-host-and-process-management)
      - [register\_host()](#register_host)
      - [register\_process()](#register_process)
      - [keepalive()](#keepalive)
      - [disconnect()](#disconnect)

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

| Key           | Description                                               |
|---------------|-----------------------------------------------------------|
| `root_dir`    | Absolute path of the directory containing the "workers"   |
|               | folder. Derived by traversing up from the calling script  |
|               | until the "workers" folder is found.                      |
| `script_dir`  | Absolute path of the directory containing the calling     |
|               | script. Determined using the script's file path.          |
| `worker_type` | Path components from "workers" folder to the calling      |
|               | script, joined using dots and the file extension removed. |
| `lock_file`   | Path to the lock file, formed by joining root_dir with    |
|               | ".lock".                                                  |
| `host_id_file`| Path to the host ID file, formed by joining root_dir with |
|               | ".host_id".                                               |
| `host_id`     | Unique UUID for the host. Read from host_id_file or       |
|               | generated and saved to host_id_file if not existing.      |
| `process_id`  | Randomly generated unique UUID for the current process.   |
| `host_name`   | Hostname of the machine where the worker is running.      |
| `foreground`  | Boolean value determining if the worker runs in the       |
|               | foreground or as a daemon. Set using a command line flag  |
|               | (--foreground or -f).                                     |
| `worker_id`   | Unique worker ID provided as a command line argument,     |
|               | must be a valid UUID.                                     |
| `parent_pid`  | Process ID of the parent process if running in the        |
|               | foreground, determined using operating system functions.  |

These initial configuration keys are reserved and cannot be used in any config
files. If they are found, an error will be raised, preventing their use.

### 4.4. Function to Configuration Key Mapping

| Function                        | Configuration Keys Used                  |
|---------------------------------|------------------------------------------|
| `connect_to_database()`         | process_id                               |
| `is_parent_alive()`             |                                          |
| `get_or_create_host_id()`       | lock_file, host_id_file                  |
| `is_valid_uuid()`               |                                          |
| `setup_logging()`               | root_dir, worker_type, worker_id,        |
|                                 | foreground                               |
| `alive()`                       | foreground, parent_pid                   |
| `run()`                         |                                          |
| `start_daemon()`                | script_dir                               |
| `register_host()`               | host_id, host_name                       |
| `register_process()`            | worker_id                                |
| `keepalive()`                   |                                          |
| `disconnect()`                  |                                          |
| `signal_handler()`              |                                          |
| `is_pid_alive()`                |                                          |
| `get_pid_for_running_process()` |                                          |
| `stop_running_process()`        |                                          |
| `parse_key_value_format()`      |                                          |
| `read_secret_config_files()`    | root_dir, script_dir                     |
| `read_config_files()`           | script_dir, root_dir                     |
| `get_calling_file_path()`       |                                          |
| `get_script_details()`          |                                          |
| `get_pid_file_path()`           | root_dir, worker_type, worker_id         |
| `setup_config()`                | **all**                                  |
| `main()`                        | worker_type, worker_id, foreground,      |
|                                 | parent_pid                               |

## 5. Signal Handling

The implementation should support handling signals for graceful termination. When a termination signal is received, the system should set a global flag, indicating that the termination has been requested.

## 6. Process Management

The system should include functions to manage processes, such as starting, stopping, and checking the status of processes. It should support running processes in the foreground or as a daemon, depending on the configuration. Additionally, the system should be able to determine if a parent process is still alive and running.

## 7. Logging

The Uniphant system should have a robust logging mechanism. It should allow setting different log levels and support logging to files and standard output (stdout). The log files should be stored in a dedicated 'log' directory, organized by worker type.

## 8. Main Function

`main()` is the entry point of the Uniphant worker script. It sets up the signal handler, configuration, and command line argument parsing. The function takes a worker_function as an argument, which is the function that will be executed as the worker task.

Function `main(worker_function)`
1. Set up signal handler for process termination requests
2. Set up configuration by reading config files and extracting script details
3. Parse command line arguments
   - Required arguments: `worker_id`, command (`start`, `restart`, `stop`, `status`)
   - Optional arguments: foreground flag (`-f` or `--foreground`)
4. Validate `worker_id` (it should be a valid UUID)
5. Connect to the database and register the host
6. Create or locate the `pid_file` for the worker
7. Handle the received command
   - If command is `start`
      - Check if the worker is already running
      - If not running, start the worker (either in foreground or background, based on the flag)
   - If command is `restart`
      - If the worker is running, stop it
      - Start the worker (either in foreground or background, based on the flag)
   - If command is `stop`
      - If the worker is running, stop it
   - If command is `status`
      - Print the current running status of the worker (running or not running)
   - If no valid command is provided, print usage and exit

## 9. Worker Function

The worker function should be provided by the user and should contain the main logic of the process. The Uniphant system should continuously execute the worker function as long as the process is alive, as determined by the 'alive' function described in step 3.

## 10. Database Connection Management

1. Create a function called `connect_to_database` that takes a configuration dictionary as input and returns a database connection. The function should:
   - Connect to the PostgreSQL database using the parameters from the configuration dictionary.
   - Set the connection's `autocommit` property to `True`.

2. Create a function called `disconnect` that takes a database connection as input and:
   - Executes a `disconnect()` function in the database.
   - Closes the database connection.

### 10.1. Database API Functions for Host and Process Management

#### register_host()

`register_host(host_id: UUID, host_name: TEXT) -> VOID`

This function registers a host in the database. It takes a `host_id` (UUID) and a `host_name` (TEXT) as input parameters. If the host with the provided `host_id` already exists, it does nothing. Otherwise, it inserts a new host record into the `hosts` table.

#### register_process()

`register_process(worker_id: UUID) -> VOID`

This function registers a process in the database. It takes a `worker_id` (UUID) as input. The `process_id` is determined from the `application_name` setting in the database connection. If a process with the same `process_id` and `worker_id` already exists, it does nothing. Otherwise, it inserts a new process record into the `processes` table.

#### keepalive()

`keepalive() -> BOOLEAN`

This function checks if a process is allowed to continue running and updates its heartbeat timestamp. The `process_id` is determined from the `application_name` setting in the database connection. If the process does not exist in the `processes` table, it returns `FALSE`, indicating that the process should terminate. If the process exists, it updates the `heartbeat_at` field for the process in the `processes` table and returns `TRUE`, allowing the process to continue running.

#### disconnect()

`disconnect() -> VOID`

This function removes a process from the `processes` table in the database. The `process_id` is determined from the `application_name` setting in the database connection. It deletes the process record with the given `process_id` from the `processes` table.
