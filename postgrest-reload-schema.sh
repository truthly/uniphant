#!/bin/sh
killall -SIGUSR1 postgrest
sleep 1
JSON=$(curl -s -H 'Content-Type: application/json' 'http://localhost:3000/')
echo "SELECT set_openapi_swagger(:'json')" | psql -X -v json="$JSON"
psql -X -c "SELECT auto_add_new_resources()"
