use crate::worker_context::WorkerContext;
use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use uuid::Uuid;
use hostname;
use dirs;

pub fn init_worker(worker_id: Uuid, foreground: bool) -> WorkerContext {
    let (root_dir, worker_dir, worker_type) = retrieve_worker_executable_info();
    let host_id_file = root_dir.join(".host_id");
    let user_home = dirs::home_dir().expect("Failed to get home directory");
    let secrets_root = user_home.join(".uniphant").join("secrets").join("workers");
    let secret_dir = secrets_root.join(worker_dir.strip_prefix(&root_dir).unwrap());

    WorkerContext {
        foreground,
        host_id: get_or_create_host_id(&host_id_file),
        host_id_file,
        host_name: hostname::get().expect("Failed to get hostname").into_string().expect("Hostname contains invalid UTF-8 characters"),
        process_id: Uuid::new_v4(),
        root_dir,
        secret_dir,
        secrets_root,
        worker_dir,
        worker_id,
        worker_type,
    }
}

fn retrieve_worker_executable_info() -> (PathBuf, PathBuf, String) {
    let current_exe_path = std::env::current_exe().expect("Could not get current executable path");
    let worker_dir = current_exe_path.parent().expect("Failed to get parent directory").to_path_buf();
    let path_components: Vec<_> = current_exe_path.components().collect();
    let workers_count = path_components.iter().filter(|&component| component.as_os_str() == "workers").count();
    if workers_count == 0 {
        panic!("The worker executable must reside under 'workers'");
    } else if workers_count > 1 {
        panic!("There should be only one 'workers' in the path");
    }
    let workers_index = path_components.iter().position(|component| component.as_os_str() == "workers").unwrap();
    let root_dir = path_components[..workers_index].iter().collect::<PathBuf>();
    let worker_type_components = path_components[workers_index + 1..].iter().map(|component| component.as_os_str().to_str().unwrap()).collect::<Vec<_>>();
    let worker_type = worker_type_components.join(".");
    (root_dir, worker_dir, worker_type)
}

fn get_or_create_host_id(host_id_file: &PathBuf) -> Uuid {
    if !host_id_file.exists() {
        let host_id = Uuid::new_v4();
        let temp_host_id_file = host_id_file.with_extension(host_id.to_string());
        File::create(&temp_host_id_file).expect("Failed to create temporary host ID file").write_all(host_id.to_string().as_bytes()).expect("Failed to write to temporary host ID file");
        // Atomically rename the temporary file to the final file
        if let Err(_) = fs::rename(&temp_host_id_file, &host_id_file) {
            // Another process has already created the host_id_file, so it's safe to ignore this error
        }

        // Clean up the temporary file if it still exists
        let _ = fs::remove_file(temp_host_id_file);
    }

    // Read the host_id from the file
    let host_id_str = fs::read_to_string(host_id_file).expect("Failed to read host ID file");
    Uuid::parse_str(&host_id_str).expect("Failed to parse host ID")
}
