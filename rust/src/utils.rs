use std::process::Command;
use std::str::FromStr;
use std::thread::sleep;
use std::time::Duration;
use uuid::Uuid;

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

pub fn stop_running_process(pid: u32) {
    let _ = Command::new("kill")
        .arg("-TERM")
        .arg(pid.to_string())
        .status();

    sleep(Duration::from_millis(200));

    while is_pid_alive(pid) {
        println!("Waiting for pid {} to die.", pid);
        sleep(Duration::from_secs(1));
    }
}
