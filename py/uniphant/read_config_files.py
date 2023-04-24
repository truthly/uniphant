from pathlib import Path
from .worker_context import WorkerContext
from typing import Dict

def read_config_files(context: WorkerContext) -> Dict[str, str]:
    config = {}
    current_dir = context.worker_dir
    while True:
        # Read regular configuration files
        uniphant_conf_path = current_dir / "uniphant.conf"
        if uniphant_conf_path.is_file():
            new_config = parse_key_value_format(uniphant_conf_path)
            for key, value in new_config.items():
                if key in config:
                    raise ValueError(f'Duplicate key "{key}" found in configuration files.')
                config[key] = value
        # Read secret configuration files
        try:
            relative_path = current_dir.relative_to(context.root_dir)
        except ValueError:
            relative_path = Path(".")
        secrets_conf_path = context.secrets_root / relative_path / "secrets.conf"
        if secrets_conf_path.is_file():
            new_secrets = parse_key_value_format(secrets_conf_path)
            for key, value in new_secrets.items():
                if key in config:
                    raise ValueError(f'Duplicate key "{key}" found in secrets files.')
                config[key] = value
        if current_dir == context.root_dir:
            break
        current_dir = current_dir.parent
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
