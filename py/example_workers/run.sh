#!/bin/bash

# List of worker scripts
scripts=(
    "api_integrations/opentdb/get_trivia_question.py"
    "api_integrations/wikipedia/search.py"
)

# Function to generate a new host_id if needed and register it
generate_and_register_host_id() {
    if [ ! -f .host_id ]; then
        host_id=$(uuidgen)
        echo -n "$host_id" > .host_id
        psql -XtAc "SELECT register_host('$host_id', '$(hostname)')"
    fi
}

# Function to extract worker_type from script path
extract_worker_type() {
    script_path=$1
    root_dir="api_integrations"
    worker_type=$(echo "${script_path#$root_dir/}" | sed 's/.py$//' | tr '/' '.')
    echo "$worker_type"
}

generate_and_register_host_id

host_id=$(<.host_id)

# Run the scripts
for script in "${scripts[@]}"; do
    worker_type=$(extract_worker_type "$script")
    worker_id=$(psql -XtAc "SELECT get_or_create_worker_id('$host_id','$worker_type')")
    python3 $script "$worker_id" "$@" &
done

# Wait for all processes to complete
wait
