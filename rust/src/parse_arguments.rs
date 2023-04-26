use std::env;
use std::process;
use uuid::Uuid;
use structopt::StructOpt;

#[derive(StructOpt, Debug)]
#[structopt(name = "app")]
pub struct Args {
    /// UUID
    #[structopt(short, long, required = false, parse(try_from_str = parse_uuid))]
    worker_id: Option<Uuid>,

    /// Run as a forking daemon
    #[structopt(short = "d", long = "daemonize")]
    daemonize: bool,
}

fn parse_uuid(src: &str) -> Result<Uuid, &'static str> {
    if utils::is_valid_uuid(src) {
        Ok(Uuid::parse_str(src).unwrap())
    } else {
        Err("The specified worker_id is not a valid UUID")
    }
}

pub fn parse_arguments() -> Args {
    let args: Args = Args::from_args();
    args
}

fn main() {
    let (worker_id, daemonize) = {
        let args = parse_arguments();
        (args.worker_id, args.daemonize)
    };

    // Your application logic here
}
