# Language-agnostic description of the Uniphant Worker interface

# Modules

## worker_context
The **WorkerContext** is an immutable data structure that stores various contextual information about a worker process.
It is used to keep track of the worker's details and to manage resources required by the worker
during its execution.

The **WorkerContext** fields are:

- **foreground**: **boolean** indicating whether the worker is running in the foreground or background.
- **host_id**: **UUID** that uniquely identifies the host on which the worker is running.
- **host_id_file**: **Path** pointing to the file that stores the host_id.
- **host_name**: **string** representing the name of the host on which the worker is running.
- **process_id**: **UUID** that uniquely identifies the worker process within the host.
- **root_dir**: **Path** pointing to the root 'workers' directory.
- **secret_dir**: **Path** pointing to a directory containing sensitive files and data used by the worker.
- **secrets_root**: **Path** pointing to the root directory where secrets are stored.
- **worker_dir**: **Path** pointing to the directory of the top-level executable that called the worker.
- **worker_id**: **UUID** that uniquely identifies the worker across all hosts.
- **worker_type**: **string** representing the type of worker (e.g., task name or category).

## init_worker

### init_worker()
init_worker() is a function that initializes the worker context with necessary details
such as host_id, host_name, process_id, and various directories.
It takes two input arguments: worker_id (a UUID) and foreground (a boolean).
The function returns a WorkerContext object containing the relevant details.

The function follows these steps to achieve the desired result:

1. Obtain the root directory, worker directory, and worker type by calling the retrieve_worker_executable_info() function.
2. Determine the host_id_file path by joining the root directory with the ".host_id" filename.
3. Find the user's home directory and construct the secrets_root path by appending ".uniphant/secrets/workers" to it.
4. Calculate the secret_dir path by taking the relative path of worker_dir with respect to root_dir
   and appending it to secrets_root.
5. Create and return a WorkerContext object with the following attributes:
    a. foreground: the input foreground value (a boolean)
    b. host_id: the host's unique identifier, obtained by calling the get_or_create_host_id() function
       with the host_id_file path
    c. host_id_file: the path to the host_id_file
    d. host_name: the hostname of the machine
    e. process_id: a unique identifier for the current process
    f. root_dir: the root 'workers' directory of the current running executable
    g. secret_dir: the path to the secret directory for this worker
    h. secrets_root: the root directory for storing secrets
    i. worker_dir: the directory of the current running executable
    k. worker_id: the worker_id (UUID)
    k. worker_type: derived from relative path between the 'workers' dir and the current running executable's path

### retrieve_worker_executable_info()

retrieve_worker_executable_info() is a function that retrieves information about the top-level executable that called
the function, specifically its root directory, worker directory, and worker type. The function returns a tuple
containing these details as paths (for root_dir and worker_dir) and a text string (for worker_type).

The function follows these steps to achieve the desired result:

1. Obtain the file path of the current running executable (current_exe_path).
2. Extract the worker directory (worker_dir) by getting the parent directory of path from step 1.
3. Split the path from step 1 into its components (path_components).
4. Count the occurrences of the word "workers" in the path components (workers_count).
    a. If workers_count is 0, raise a ValueError,
       as the worker executable must reside under a directory named 'workers'.
    b. If workers_count is greater than 1, raise a ValueError,
       as there must be only one 'workers' directory in the path.
5. Find the index of the 'workers' directory in the path components (workers_index).
6. Determine the root directory (root_dir) by taking the path components up to and including the 'workers' directory,
   and joining them into a path.
7. Determine the worker type (worker_type) by taking the path components after the 'workers' directory, joining them
   with dots, and removing the file extension if present.
8. Return the root directory, worker directory, and worker type as a tuple.

### get_or_create_host_id()
get_or_create_host_id() is a function that retrieves a host's unique identifier (UUID) or generates and stores one
if it doesn't exist. The input is the path to the file that should store the host_id.
The function returns the host_id as a UUID.

The function follows these steps to achieve the desired result:

1. Check if the host_id_file exists.
    a. If it does not exist, generate a new UUID (host_id) and create a temporary file with a unique name.
    b. Write the newly generated host_id to the temporary file.
    c. Attempt to atomically rename the temporary file to the final file (host_id_file).
    This ensures that only one process can create the host_id_file, avoiding race conditions.
    d. If a FileExistsError is raised, it means another process has already created the host_id_file,
    so the error is ignored.
    e. If the temporary file still exists after the renaming attempt, it is removed.
2. Read the host_id from the host_id_file and return it as a UUID.

## read_config_files

### read_config_files()

read_config_files() is a function that takes a WorkerContext object as input and returns a dictionary containing
key-value pairs loaded from configuration files in the worker's directory hierarchy. The function is designed to handle
both regular and secret configuration files.

The function starts by traversing up the directory hierarchy from the worker's directory to the root directory,
collecting all directories in a list. For each directory, it checks if a file named "uniphant.conf" exists. If it does,
the function parses the file using the parse_key_value_format() function and stores the key-value pairs in the 'config'
dictionary. If any duplicate keys are found, the function raises a ValueError.

Next, the function repeats a similar process for secret configuration files. It traverses up the directory hierarchy,
this time calculating the relative path of each directory from the root directory. For each relative path, the function
checks if a file named "secrets.conf" exists in the corresponding subdirectory of 'secrets_root'. If it does,
the function parses the file, and stores the key-value pairs in the 'config' dictionary, raising a ValueError in case
of any duplicate keys.

Finally, the function returns the 'config' dictionary containing key-value pairs loaded from both regular and secret
configuration files.
