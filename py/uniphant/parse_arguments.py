import argparse
import sys
from typing import Tuple
from .utils import is_valid_uuid

def parse_arguments() -> Tuple[str, str, bool]:
    parser = argparse.ArgumentParser()
    parser.add_argument('worker_id',
                        help='Worker ID')
    parser.add_argument('command',
                        nargs=1,
                        choices=["start", "restart", "stop", "status"],
                        help='Command to run')
    parser.add_argument('-f', '--foreground',
                        action='store_true',
                        default=False,
                        help='Run in the foreground')
    args = parser.parse_args()

    # Extract parsed arguments
    command = args.command[0]
    worker_id = args.worker_id
    foreground = args.foreground

    if not is_valid_uuid(worker_id):
        print(f"The specified worker_id {worker_id} is not a valid UUID")
        parser.print_usage(sys.stderr)
        sys.exit(2)

    return command, worker_id, foreground
