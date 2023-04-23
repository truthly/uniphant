use std::collections::HashMap;
use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::path::PathBuf;

use crate::worker_context::WorkerContext;

pub fn read_config_files(context: &WorkerContext) -> HashMap<String, String> {
    let mut config = HashMap::new();

    let mut current_dir = context.script_dir.clone();
    let mut directories = Vec::new();

    while current_dir != context.root_dir {
        directories.push(current_dir.clone());
        current_dir = current_dir.parent().unwrap().to_path_buf();
    }
    directories.push(context.root_dir.clone());

    for directory in directories {
        let conf_file = directory.join("uniphant.conf");
        if conf_file.exists() {
            let parsed_data = parse_key_value_format(&conf_file).expect("Failed to parse uniphant.conf");
            for (key, value) in parsed_data {
                if config.contains_key(&key) {
                    panic!("Duplicate config key: {}", key);
                }
                config.insert(key, value);
            }
        }
    }

    let mut current_dir = context.script_dir.clone();
    let mut relative_dirs = Vec::new();

    while current_dir != context.root_dir {
        let rel_dir = current_dir.strip_prefix(&context.root_dir).expect("Failed to strip prefix");
        relative_dirs.push(rel_dir.to_path_buf());
        current_dir = current_dir.parent().unwrap().to_path_buf();
    }

    for rel_dir in relative_dirs {
        let secret_conf_file = context.secrets_root.join(rel_dir).join("secrets.conf");
        if secret_conf_file.exists() {
            let parsed_data = parse_key_value_format(&secret_conf_file).expect("Failed to parse secrets.conf");
            for (key, value) in parsed_data {
                if config.contains_key(&key) {
                    panic!("Duplicate config key: {}", key);
                }
                config.insert(key, value);
            }
        }
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
