#!/bin/sh
./ubuntu-install.sh
curl 'http://localhost/api/rpc/sign_up' \
  -H 'Content-Type: application/json;charset=utf-8' \
  --data '{"username":"test"}' \
  -w "\n"
COUNT_CREDENTIAL_CHALLENGES=$(psql -A -t -c "SELECT COUNT(*) FROM users" uniphant)
echo "::set-output name=count_credential_challenges::$COUNT_CREDENTIAL_CHALLENGES"
