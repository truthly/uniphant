#!/bin/sh
# postgresql:
sudo apt-get -y dist-upgrade
sudo apt-get -y install gnupg
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql postgresql-server-dev-13 build-essential
sudo service postgresql start
sudo -u postgres createuser -s "$USER"
createdb uniphant
createuser api -L -s
createuser web_anon -L
createuser postgrest -I
# pg-cbor:
git clone https://github.com/truthly/pg-cbor.git
(cd pg-cbor && make && sudo make install && make installcheck)
# pg-ecdsa:
git clone https://github.com/truthly/pg-ecdsa.git
(cd pg-ecdsa && make && sudo make install && make installcheck)
# pg-webauthn:
git clone https://github.com/truthly/pg-webauthn.git
(cd pg-webauthn && make && sudo make install && make installcheck)
# uniphant:
git clone https://github.com/truthly/uniphant.git
cd uniphant || exit
(make && sudo make install && make installcheck)
psql -c "CREATE EXTENSION uniphant CASCADE" uniphant
# postgrest:
wget --quiet https://github.com/PostgREST/postgrest/releases/download/v7.0.1/postgrest-v7.0.1-linux-x64-static.tar.xz
tar xvf postgrest-v7.0.1-linux-x64-static.tar.xz
sudo cp postgrest /bin/postgrest
sudo mkdir -p /etc/postgrest
sudo cp postgrest.conf /etc/postgrest/config
sudo cp postgrest.service /etc/systemd/system/postgrest.service
sudo adduser --system --no-create-home postgrest
sudo systemctl enable postgrest
sudo systemctl start postgrest
# nginx:
sudo apt-get -y install nginx-light
sudo rm /etc/nginx/sites-enabled/default
sudo cp nginx.conf /etc/nginx/sites-available/uniphant
sudo ln -s /etc/nginx/sites-available/uniphant /etc/nginx/sites-enabled/uniphant
sudo ln -s "$HOME/uniphant/demo" /var/www/html/uniphant
sudo systemctl restart nginx
