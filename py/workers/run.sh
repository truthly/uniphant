#!/bin/bash
export PGDATABASE=uniphant
export PGUSER=uniphant

# List of worker scripts
scripts=(
    "opentdb/get_trivia_question"
    "wikipedia/search"
)

# Function to generate a new host_id if needed and register it
generate_and_register_host_id() {
    if [ -f .host_id ]; then
        host_id=$(<.host_id)
    else
        host_id=$(uuidgen)
        echo -n "$host_id" > .host_id
    fi
    psql -XtAc "SELECT register_host('$host_id', '$(hostname)')" >/dev/null
}

# Function to extract worker_type from script path
extract_worker_type() {
    script_path=$1
    root_dir="workers"
    worker_type=$(echo "${script_path#$root_dir/}" | tr '/' '.')
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
