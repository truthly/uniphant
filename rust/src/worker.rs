use std::collections::HashMap;
use std::process;
use std::thread;
use std::time::Duration;
use std::os::unix::process::parent_id;
use std::fs;

use daemonize::Daemonize;
use log::{error, info};
use postgres::{Client, Config};
use uuid::Uuid;

use crate::database::{
    connect, database_config, register_host, register_process, keepalive, delete_process, get_worker_process_id
};
use crate::init_worker::init_worker;
use crate::parse_arguments::{Command, parse_arguments};
use crate::read_config_files::read_config_files;
use crate::setup_logging::setup_logging;
use crate::utils::{is_pid_alive, stop_worker_process};
pub use crate::worker_context::WorkerContext;

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
    let dbconfig = database_config(
        config.get("PGDATABASE").map(|s| s.as_str()).or_else(|| Some("uniphant")),
        config.get("PGUSER").map(|s| s.as_str()).or_else(|| Some("uniphant")),
        config.get("PGPASSWORD").map(|s| s.as_str()),
        config.get("PGHOST").map(|s| s.as_str()).or_else(|| Some("localhost")),
        config.get("PGPORT").and_then(|s| s.parse::<u16>().ok()),
    );
    let mut connection = connect(dbconfig.clone());

    // Register host
    register_host(&mut connection, context.host_id, &context.host_name);

    // Check if worker is already running
    let existing_process_id = get_worker_process_id(&mut connection, context.worker_id);
    let already_running = existing_process_id.is_some();

    // Handle command
    match command {
        Command::Start => {
            if already_running {
                eprintln!("Cannot start {} worker with ID {} since it is already running.", context.worker_type, worker_id);
                std::process::exit(1);
            }
            println!("Starting {} worker with ID {}.", context.worker_type, worker_id);
            if foreground {
                run(worker_function, connection, &config, &context);
            } else {
                // Disconnect to reconnect since we cannot share a connection with fork.
                drop(connection);
                start_daemon(worker_function, dbconfig, &config, context);
            }
        }
        Command::Restart => {
            if already_running {
                println!("Stopping {} worker with ID {}.", context.worker_type, worker_id);
                stop_worker_process(&mut connection, context.worker_id, existing_process_id.unwrap());
            }
            println!("Starting {} worker with ID {}.", context.worker_type, worker_id);
            if foreground {
                run(worker_function, connection, &config, &context);
            } else {
                // Disconnect to reconnect since we cannot share a connection with fork.
                drop(connection);
                start_daemon(worker_function, dbconfig, &config, context);
            }
        }
        Command::Stop => {
            if already_running {
                println!("Stopping {} worker with ID {}.", context.worker_type, worker_id);
                stop_worker_process(&mut connection, context.worker_id, existing_process_id.unwrap());
            } else {
                eprintln!("Cannot stop {} worker with ID {} since it is not running.", context.worker_type, worker_id);
                std::process::exit(1);
            }
        }
        Command::Status => {
            if already_running {
                println!("Worker {} with ID {} is running.", context.worker_type, worker_id);
            } else {
                println!("Worker {} with ID {} is not running.", context.worker_type, worker_id);
            }
        }
    }
}

pub fn should_run(connection: &mut Client, process_id: Uuid, foreground: bool) -> bool {
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

fn start_daemon(
    worker_function: WorkerFunction,
    dbconfig: Config,
    config: &HashMap<String, String>,
    context: WorkerContext,
) {
    // Create the PID directory path
    let pid_dir = context.root_dir.join("pid").join(&context.worker_type);
    if let Err(e) = fs::create_dir_all(&pid_dir) {
        eprintln!("Error creating PID directory: {}", e);
        process::exit(1);
    }

    // Construct the PID file path
    let pid_file = pid_dir.join(format!("{}.pid", context.worker_id));

    let daemonize = Daemonize::new()
        .working_directory(context.worker_dir.clone())
        .pid_file(pid_file);

    match daemonize.start() {
        Ok(_) => {
            let connection = connect(dbconfig);
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

    while should_run(&mut connection, context.process_id, context.foreground) {
        match worker_function(&mut connection, &config, context) {
            Ok(_) => {}
            Err(e) => {
                error!("Error running worker function: {}", e);
            }
        }
        thread::sleep(Duration::from_secs(1));
    }

    info!("Stopped PID: {}", pid);
    delete_process(&mut connection, context.process_id);
    connection.close().expect("Failed to close connection");
}
