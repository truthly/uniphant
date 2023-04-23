use std::env;
use std::process;
use std::str::FromStr;
use uuid::Uuid;
use crate::utils::is_valid_uuid;

pub enum Command {
    Start,
    Restart,
    Stop,
    Status,
}

impl FromStr for Command {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "start" => Ok(Command::Start),
            "restart" => Ok(Command::Restart),
            "stop" => Ok(Command::Stop),
            "status" => Ok(Command::Status),
            _ => Err(format!("Invalid command: {}", s)),
        }
    }
}

pub fn parse_arguments() -> (Command, Uuid, bool) {
    let mut args = env::args().skip(1);
    let worker_id = match args.next() {
        Some(id) => id,
        None => {
            eprintln!("Worker UUID is required");
            print_usage_and_exit(1);
        }
    };
    let command = match args.next() {
        Some(cmd) => cmd.parse::<Command>().unwrap_or_else(|e| {
            eprintln!("{}", e);
            print_usage_and_exit(1);
        }),
        None => {
            eprintln!("Command is required");
            print_usage_and_exit(1);
        }
    };
    let foreground = args.any(|arg| arg == "-f" || arg == "--foreground");

    if !is_valid_uuid(&worker_id) {
        eprintln!(
            "The specified worker_id {} is not a valid UUID",
            worker_id
        );
        print_usage_and_exit(2);
    }

    let worker_uuid = Uuid::parse_str(&worker_id).unwrap();
    (command, worker_uuid, foreground)
}

fn print_usage_and_exit(code: i32) -> ! {
    eprintln!("Usage: uniphant_worker <worker_id> <command> [-f | --foreground]");
    eprintln!("Commands: start, restart, stop, status");
    process::exit(code);
}
