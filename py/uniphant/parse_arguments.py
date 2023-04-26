from argparse import ArgumentParser
from sys import stderr, exit
from typing import Tuple, Optional
from uuid import UUID
from .utils import is_valid_uuid

def parse_arguments() -> Tuple[Optional[UUID], bool]:
    parser = ArgumentParser()
    parser.add_argument('worker_id',
                        nargs='?',
                        default=None,
                        help='UUID')
    parser.add_argument('-d', '--daemonize',
                        action='store_true',
                        default=False,
                        help='run as a forking daemon')
    args = parser.parse_args()
    worker_id: UUID = None
    daemonize: bool = args.daemonize
    if args.worker_id is not None:
        if not is_valid_uuid(args.worker_id):
            print(f"The specified worker_id {args.worker_id} is not a valid UUID")
            parser.print_usage(stderr)
            exit(2)
        worker_id = UUID(args.worker_id)
    return worker_id, daemonize
