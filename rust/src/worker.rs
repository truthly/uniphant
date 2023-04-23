use std::collections::HashMap;
use std::process;
use std::thread;
use std::time::Duration;
use std::os::unix::process::parent_id;
use std::fs;

use daemonize::Daemonize;
use log::{error, info};
use postgres::Client;
use uuid::Uuid;

use crate::database::{
    connect, get_existing_process_info, keepalive, register_host, register_process, delete_process
};
use crate::init_worker::init_worker;
use crate::parse_arguments::{Command, parse_arguments};
use crate::read_config_files::read_config_files;
use crate::setup_logging::setup_logging;
use crate::utils::{is_pid_alive, stop_running_process};
use crate::worker_context::WorkerContext;

pub type WorkerFunction = fn(
    &mut Client,
    &HashMap<String, String>,
    &WorkerContext,
) -> Result<(), Box<dyn std::error::Error>>;

pub fn worker(worker_function: WorkerFunction) {
    let (command, worker_id, foreground) = parse_arguments();

    // Init worker context
    let context = init_worker(worker_id, foreground);

    // Setup config
    let config = read_config_files(&context);

    // Connect to PostgreSQL database
    let mut connection = connect();

    // Register host
    register_host(&mut connection, context.host_id, &context.host_name);

    // Check if worker is already running
    let (existing_process_id, existing_pid) = match get_existing_process_info(&mut connection, context.host_id, context.worker_id) {
        Some((process_id, pid)) => (Some(process_id), Some(pid)),
        None => (None, None),
    };
    let already_running = match existing_pid {
        Some(pid) if is_pid_alive(pid) => true,
        Some(_) => {
            if let Some(process_id) = existing_process_id {
                println!(
                    "Clean-up {} worker with ID {} since it is no longer running.",
                    context.worker_type, worker_id
                );
                delete_process(&mut connection, process_id);
            }
            false
        }
        None => false,
    };

    // Handle command
    match command {
        Command::Start => {
            if already_running {
                if let Some(pid) = existing_pid {
                    eprintln!(
                        "Cannot start {} worker with ID {} since it is already running with PID: {}",
                        context.worker_type, worker_id, pid
                    );
                }
                process::exit(1);
            } else {
                println!("Starting {} worker with ID {}.", context.worker_type, worker_id);
                if foreground {
                    run(worker_function, connection, &config, &context);
                } else {
                    start_daemon(worker_function, connection, config, context);
                }
            }
        }
        Command::Restart => {
            if already_running {
                println!("Restarting {} worker with ID {}.", context.worker_type, worker_id);
                if let Some(pid) = existing_pid {
                    stop_running_process(pid);
                }
            } else {
                println!(
                    "Starting {} worker with ID {} (it wasn't running).",
                    context.worker_type, worker_id
                );
            }
            if foreground {
                run(worker_function, connection, &config, &context);
            } else {
                start_daemon(worker_function, connection, config, context);
            }
        }
        Command::Stop => {
            if already_running {
                println!("Stopping {} worker with ID {}.", context.worker_type, worker_id);
                if let Some(pid) = existing_pid {
                    stop_running_process(pid);
                }
            } else {
                eprintln!(
                    "Cannot stop {} worker with ID {} since it is not running.",
                    context.worker_type, worker_id
                );
                process::exit(1);
            }
        }
        Command::Status => {
            if already_running {
                if let Some(pid) = existing_pid {
                    println!(
                        "Worker {} with ID {} is running with PID: {}",
                        context.worker_type, worker_id, pid
                    );
                }
            } else {
                println!(
                    "Worker {} with ID {} is not running.",
                    context.worker_type, worker_id
                );
            }
        }
    }
}

fn start_daemon(
    worker_function: WorkerFunction,
    connection: Client,
    config: HashMap<String, String>,
    context: WorkerContext,
) {
    // Disconnect since daemon will fork and child cannot share database
    // connection with parent.
    connection.close().expect("Failed to close connection");

    // Create the PID directory path
    let pid_dir = context.root_dir.join("pid").join(&context.worker_type);
    if let Err(e) = fs::create_dir_all(&pid_dir) {
        eprintln!("Error creating PID directory: {}", e);
        process::exit(1);
    }

    // Construct the PID file path
    let pid_file = pid_dir.join(format!("{}.pid", context.worker_id));

    let daemonize = Daemonize::new()
        .working_directory(context.script_dir.clone())
        .pid_file(pid_file);

    match daemonize.start() {
        Ok(_) => {
            let connection = connect();
            run(worker_function, connection, &config, &context);
        }
        Err(e) => {
            eprintln!("Error daemonizing: {}", e);
            process::exit(1);
        }
    }
}

fn run(
    worker_function: WorkerFunction,
    mut connection: Client,
    config: &HashMap<String, String>,
    context: &WorkerContext,
) {
    setup_logging(context);
    let pid = process::id();
    info!("Started PID: {}", pid);
    register_process(&mut connection, context.process_id, context.worker_id, pid as i32);

    loop {
        match worker_function(&mut connection, config, context) {
            Ok(_) => {}
            Err(e) => {
                error!("Error running worker function: {}", e);
            }
        }
        if !should_run(&mut connection, context.process_id, context.foreground) {
            break;
        }
        thread::sleep(Duration::from_secs(1));
    }

    info!("Stopped PID: {}", pid);
    delete_process(&mut connection, context.process_id);
    connection.close().expect("Failed to close connection");
}

fn should_run(connection: &mut Client, process_id: Uuid, foreground: bool) -> bool {
    // Stop if termination has been requested, via the database
    if !keepalive(connection, process_id) {
        return false;
    }

    // Stop if running in foreground and the parent process has died
    if foreground && !is_pid_alive(parent_id()) {
        return false;
    }

    // Otherwise, the process should continue running
    true
}
