import argparse
import sys
from typing import Tuple
from .utils import is_valid_uuid
from uuid import UUID

def parse_arguments() -> Tuple[str, UUID, bool]:
    parser = argparse.ArgumentParser("Uniphant Worker")
    parser.add_argument('worker_id',
                        help='Worker UUID')
    parser.add_argument('command',
                        nargs=1,
                        choices=["start", "restart", "stop", "status"],
                        help='Command to run')
    parser.add_argument('-f', '--foreground',
                        action='store_true',
                        default=False,
                        help='Do not daemonize')
    args = parser.parse_args()

    if not is_valid_uuid(args.worker_id):
        print(f"The specified worker_id {args.worker_id} is not a valid UUID")
        parser.print_usage(sys.stderr)
        sys.exit(2)

    # Extract parsed arguments
    command = args.command[0]
    worker_id = UUID(args.worker_id)
    foreground = args.foreground

    return command, worker_id, foreground
