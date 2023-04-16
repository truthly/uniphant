#!/bin/bash

# List of scripts
scripts=(
    "api_integrations/opentdb/get_trivia_question.py"
    "api_integrations/wikipedia/search.py"
)

# Run the scripts
for script in "${scripts[@]}"; do
    worker_ids=$(python3 $script list | awk '{print $1}')

    for worker_id in $worker_ids; do
        python3 $script --worker-id "$worker_id" "$@" &
    done
done

# Wait for all processes to complete
wait
