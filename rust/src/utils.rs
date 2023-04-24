use std::process::Command;
use std::str::FromStr;
use std::thread::sleep;
use std::time::Duration;
use uuid::Uuid;
use postgres::Client;

use crate::database::{
    request_process_termination, get_worker_process_id
};

pub fn is_valid_uuid(text: &str) -> bool {
    Uuid::from_str(text).is_ok()
}

pub fn is_pid_alive(pid: u32) -> bool {
    Command::new("kill")
        .arg("-0")
        .arg(pid.to_string())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

pub fn stop_worker_process(connection: &mut Client, worker_id: Uuid, process_id: Uuid) -> () {
    request_process_termination(connection, process_id);
    sleep(Duration::from_secs(1));
    while get_worker_process_id(connection, worker_id).is_some() {
        println!("Waiting for process {} to die.", process_id);
        sleep(Duration::from_secs(1));
    }
}
