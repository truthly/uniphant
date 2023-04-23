use crate::worker_context::WorkerContext;
use simplelog::{ConfigBuilder, LevelFilter, SimpleLogger, WriteLogger};
use std::fs::File;

pub fn setup_logging(context: &WorkerContext) -> () {
    let log_dir = context.root_dir.join("log").join(&context.worker_type);
    std::fs::create_dir_all(&log_dir).expect("Failed to create log directory");

    let log_file = log_dir.join(format!("{}.log", context.worker_id));
    let file = File::create(log_file).expect("Failed to create log file");

    let config = ConfigBuilder::new()
        .set_time_format_rfc3339()
        .set_thread_level(LevelFilter::Off)
        .set_target_level(LevelFilter::Off)
        .set_location_level(LevelFilter::Off)
        .build();

    let mut loggers: Vec<Box<dyn simplelog::SharedLogger>> = vec![WriteLogger::new(
        LevelFilter::Info,
        config.clone(),
        file,
    )];

    if context.foreground {
        loggers.push(SimpleLogger::new(LevelFilter::Info, config));
    }

    simplelog::CombinedLogger::init(loggers).expect("Failed to initialize logging");
}
