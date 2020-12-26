#!/bin/sh
sudo apt-get -y dist-upgrade
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql postgresql-server-dev-13 build-essential nginx-light
sudo service postgresql start
sudo -u postgres createuser -s "$USER"
createdb uniphant
git clone https://github.com/truthly/pg-cbor.git
(cd pg-cbor && make && sudo make install && make installcheck)
git clone https://github.com/ameensol/pg-ecdsa.git
(cd pg-ecdsa && PG_CFLAGS=-Wno-vla make && sudo make install && make installcheck)
git clone https://github.com/truthly/pg-webauthn.git
(cd pg-webauthn && make && sudo make install && make installcheck)
wget --quiet https://github.com/PostgREST/postgrest/releases/download/v7.0.1/postgrest-v7.0.1-linux-x64-static.tar.xz
tar xvf postgrest-v7.0.1-linux-x64-static.tar.xz
sudo cp postgrest /bin/postgrest
createuser api -L -s
createuser web_anon -L
createuser postgrest -I -l
git clone https://github.com/truthly/uniphant.git
(cd uniphant && make && sudo make install && make installcheck)
psql -c "CREATE EXTENSION uniphant CASCADE" uniphant
sudo mkdir -p /etc/postgrest
sudo cp postgrest.conf /etc/postgrest/config
sudo cp postgrest.service /etc/systemd/system/postgrest.service
sudo adduser --system --no-create-home postgrest
sudo systemctl enable postgrest
sudo systemctl start postgrest
sudo rm /etc/nginx/sites-enabled/default
sudo cp nginx.conf /etc/nginx/sites-available/uniphant
sudo ln -s /etc/nginx/sites-available/uniphant /etc/nginx/sites-enabled/uniphant
sudo ln -s "$HOME/uniphant/demo" /var/www/html/uniphant
sudo systemctl restart nginx
curl 'http://localhost/api/rpc/init_credential' \
  -H 'Content-Type: application/json;charset=utf-8' -w "\n" \
  --data '{"username":"test","display_name":"Test User"}'
COUNT_CREDENTIAL_CHALLENGES=$(psql -A -t -c "SELECT COUNT(*) FROM webauthn.credential_challenges" uniphant)
echo "::set-output name=count_credential_challenges::$COUNT_CREDENTIAL_CHALLENGES"
