from pathlib import Path
from .worker_state import WorkerState
from typing import Dict

def read_config_files(state: WorkerState) -> Dict[str, str]:
    config = {}
    current_dir = state.script_dir
    root_dir = state.root_dir
    directories = []
    while current_dir != root_dir:
        directories.append(current_dir)
        current_dir = current_dir.parent
    directories.append(root_dir)
    for directory in directories:
        conf_file = directory / "uniphant.conf"
        if conf_file.exists():
            parsed_data = parse_key_value_format(conf_file)
            for key, value in parsed_data.items():
                if key in config:
                    raise ValueError(f"Duplicate config key: {key}")
                config[key] = value
    # Merge key=value pairs from secret config files and return the secret_dir
    # in which integrations can store secret files/data received from APIs,
    # such as an API key obtained when logging in with a username/password.
    current_dir = state.script_dir
    relative_dirs = []
    while current_dir != state.root_dir:
        relative_dirs.append(current_dir.relative_to(state.root_dir))
        current_dir = current_dir.parent
    for rel_dir in relative_dirs:
        secret_conf_file = state.secrets_root / rel_dir / 'secrets.conf'
        if secret_conf_file.exists():
            parsed_data = parse_key_value_format(secret_conf_file)
            for key, value in parsed_data.items():
                if key in config:
                    raise ValueError(f"Duplicate config key: {key}")
                config[key] = value
    return config

def parse_key_value_format(conf_file: Path):
    config_data = {}
    with conf_file.open('r') as file:
        for line in file:
            if line.strip() == '' or line.strip().startswith('#'):
                continue
            key, value = line.strip().split('=', 1)
            config_data[key.strip()] = value.strip()
    return config_data
