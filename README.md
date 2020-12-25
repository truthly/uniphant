<h1 id="top">🦄🐘<code>uniphant</code></h1>

1. [About](#about)
2. [Dependencies](#dependencies)
3. [Installation](#installation)

<h2 id="about">1. About</h2>

`uniphant` is a full-stack demo project on how to integrate various PostgreSQL-centric components to work nicely together.

<h2 id="dependencies">2. Dependencies</h2>

[🔐🐘webauthn] for the WebAuthn Server.

[PostgREST](https://postgrest.org/en/v7.0.0/) for the API.

[🔐🐘webauthn]: https://github.com/truthly/pg-webauthn

<h2 id="installation">3. Installation</h2>

<h3 id="installation-osx">3.1. Running Ubuntu in VirtualBox</h3>

1. Download and install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
1. Download [ubuntu-20.04.1-live-server-amd64.iso](https://releases.ubuntu.com/20.04/ubuntu-20.04.1-live-server-amd64.iso)
1. Open VirtualBox
1. Click **New** and follow instructions
1. Click **Settings** and goto **Network**, Attached to: **NAT**, Click **Port Forwarding**
1. Add Host Port **2200** Guest Port **22**, leave Host IP and Guest IP blank
1. Add Host Port **8080** Guest Port **80**, leave Host IP and Guest IP blank
1. Click **OK**, Click **OK**
1. Click **Start**
1. Select **ubuntu-20.04.1-live-server-amd64.iso**
1. Follow instructions
1. To simplify logging in to the machine, you can enter your Github username to install its SSH key.
1. Install OpenSSH server: **YES**
1. Import SSH identity: **from GitHub**
1. Github username: *enter your Github-username*

<h3 id="installation-osx">3.2. Ubuntu 20.04.1</h3>

The following exact step-by-step instructions assume a clean installation of Ubuntu.

```sh
sudo apt -y dist-upgrade
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt update
sudo apt -y install postgresql postgresql-server-dev-13 build-essential
sudo -u postgres createuser -s $USER
createdb uniphant
git clone https://github.com/truthly/pg-cbor.git
cd pg-cbor
make
sudo make install
make installcheck
cd ..
git clone https://github.com/ameensol/pg-ecdsa.git
cd pg-ecdsa
PG_CFLAGS=-Wno-vla make
sudo make install
make installcheck
cd ..
git clone https://github.com/truthly/pg-webauthn.git
cd pg-webauthn
make
sudo make install
make installcheck
cd ..
sudo apt -y install nginx-light
git clone https://github.com/truthly/uniphant.git
cd uniphant
make
sudo make install
createuser api -L -s
createuser web_anon -L
createuser postgrest -I -l
psql -c "CREATE EXTENSION uniphant CASCADE"
psql -c "GRANT USAGE ON SCHEMA api TO web_anon"
psql -c "GRANT web_anon TO postgrest"
psql -c "GRANT USAGE ON SCHEMA webauthn TO web_anon"
make installcheck
wget --quiet https://github.com/PostgREST/postgrest/releases/download/v7.0.1/postgrest-v7.0.1-linux-x64-static.tar.xz
tar xvf postgrest-v7.0.1-linux-x64-static.tar.xz
sudo cp postgrest /bin/postgrest
sudo mkdir -p /etc/postgrest
sudo cp postgrest.conf /etc/postgrest/config
sudo cp postgrest.service /etc/systemd/system/postgrest.service
sudo adduser --system --no-create-home postgrest
sudo systemctl enable postgrest
sudo systemctl start postgrest
sudo rm /etc/nginx/sites-enabled/default
sudo cp nginx.conf /etc/nginx/sites-available/uniphant
sudo ln -s /etc/nginx/sites-available/uniphant /etc/nginx/sites-enabled/uniphant
sudo ln -s $HOME/uniphant/demo /var/www/html/uniphant
sudo systemctl restart nginx
```

Next, you can connect with a browser to `http://localhost:8080` and test sign-up and sign-in.

After sign-in and sign-up, you will see the new user in the `users` table and the generated token in the `tokens` table.

```sh
uniphant@uniphant:~/uniphant$ psql
psql (13.1 (Ubuntu 13.1-1.pgdg20.04+1))
Type "help" for help.

uniphant=# \x
Expanded display is on.
```

```sql
SELECT * FROM users;

-[ RECORD 1 ]------+-----------------------------------------------------------------------------------------------------------------------------------
user_id            | 1
user_random_id     | \x1a31c094bc47e3d18f04bb9881447da3f0b48a3937139a0980d8b9c2c82a7d3502df96c4718d7e0d69ba22e44a8ddc6fec57875c65ec25a0fcf8a8b39c0dfce8
username           | alex.p.mueller@example.com
display_name       | Alex P. Müller
sign_up_at         | 2020-12-25 19:55:01.411471+00
sign_up_ip         | 127.0.0.1
make_credential_at | 2020-12-25 19:55:03.713913+00
make_credential_ip | 127.0.0.1

SELECT * FROM tokens;

-[ RECORD 1 ]-------------------------------------
token       | ea487db4-d1c6-460a-8cf6-68da3e69d183
user_id     | 1
sign_in_at  | 2020-12-25 19:55:10.28184+00
sign_out_at |
```
