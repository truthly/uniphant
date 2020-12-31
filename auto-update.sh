#!/bin/sh
# sudo chgrp ubuntu /usr/share/postgresql/13/extension
# sudo chmod 775 /usr/share/postgresql/13/extension
# crontab -e
# */1 * * * * /home/ubuntu/uniphant/auto-update.sh
# sudo crontab -e -u postgrest
# */1 * * * * killall -SIGUSR1 postgrest
cd $(dirname "$0") || exit
DATABASE_NAME=uniphant
(cd pg-cbor && git pull && make && make install && make installcheck && psql -c "ALTER EXTENSION cbor UPDATE" $DATABASE_NAME)
(cd pg-ecdsa && make && make install && make installcheck && psql -c "ALTER EXTENSION ecdsa UPDATE" $DATABASE_NAME)
(cd pg-webauthn && make && make install && make installcheck && psql -c "ALTER EXTENSION webauthn UPDATE" $DATABASE_NAME)
git pull && make && make install && make installcheck && psql -c "ALTER EXTENSION uniphant UPDATE" $DATABASE_NAME
