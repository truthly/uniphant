use std::collections::HashMap;
use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::path::PathBuf;

use crate::worker_context::WorkerContext;

pub fn read_config_files(context: &WorkerContext) -> HashMap<String, String> {
    let mut config = HashMap::new();
    let mut current_dir = context.worker_dir.clone();
    while current_dir != context.root_dir {
        let uniphant_conf_path = current_dir.join("uniphant.conf");
        if uniphant_conf_path.exists() {
            let parsed_config = parse_key_value_format(&uniphant_conf_path).expect("Failed to parse uniphant.conf");
            for (key, value) in parsed_config {
                if config.contains_key(&key) {
                    panic!("Duplicate config key: {}", key);
                }
                config.insert(key, value);
            }
        }
        let relative_path = current_dir.strip_prefix(&context.root_dir).expect("Failed to get relative path");
        let secrets_conf_path = context.secrets_root.join(relative_path).join("secrets.conf");
        if secrets_conf_path.exists() {
            let parsed_secret_config = parse_key_value_format(&secrets_conf_path).expect("Failed to parse secrets.conf");
            for (key, value) in parsed_secret_config {
                if config.contains_key(&key) {
                    panic!("Duplicate config key: {}", key);
                }
                config.insert(key, value);
            }
        }
        current_dir = current_dir.parent().unwrap().to_path_buf();
    }
    config
}

fn parse_key_value_format(conf_file: &PathBuf) -> io::Result<HashMap<String, String>> {
    let file = File::open(conf_file)?;
    let reader = BufReader::new(file);
    let mut config_data = HashMap::new();
    for line in reader.lines() {
        let line = line?;
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let mut parts = line.splitn(2, '=');
        let key = parts.next().unwrap().trim().to_string();
        let value = parts.next().unwrap().trim().to_string();
        config_data.insert(key, value);
    }
    Ok(config_data)
}
