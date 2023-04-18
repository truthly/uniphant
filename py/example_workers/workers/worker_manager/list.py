    # Handle `list` command.
    #
    # The list command isn't worker_id specific and is therefore
    # handled before worker_id is set.
    if command == 'list':
        worker_ids = ensure_worker_exists_and_get_ids(config, connection)
        for worker_id in worker_ids:
            print(worker_id + " " + worker_type)
        sys.exit(0)
