<h1 id="top">🦄🐘<code>uniphant</code></h1>

<p align="left">
  <a href="https://github.com/truthly/uniphant/actions"><img alt="build-test status" src="https://github.com/truthly/uniphant/workflows/build-test/badge.svg"></a>
  <a href="https://github.com/truthly/uniphant/actions"><img alt="super-linter status" src="https://github.com/truthly/uniphant/workflows/super-linter/badge.svg"></a>  
</p>

1. [About](#about)
1. [Dependencies](#dependencies)
1. [Installation](#installation)
    1. [Running Ubuntu in VirtualBox](#virtualbox)
    1. [Ubuntu 20.04.1](#ubuntu)
    1. [Setting up SSL/TLS using Let's Encrypt/Certbot](#certbot)

[Running Ubuntu in VirtualBox]: #virtualbox

<h2 id="about">1. About</h2>

`uniphant` is a full-stack demo project on how to integrate various PostgreSQL-centric components to work nicely together.

For a live demo of the latest released version, check out [https://uniphant.dev](https://uniphant.dev).

<h2 id="dependencies">2. Dependencies</h2>

[🔐🐘webauthn] for the WebAuthn Server.

[PostgREST](https://postgrest.org/en/v7.0.0/) for the API.

[🔐🐘webauthn]: https://github.com/truthly/pg-webauthn

<h2 id="installation">3. Installation</h2>

<h3 id="virtualbox">3.1. Running Ubuntu in VirtualBox</h3>

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
1. To simplify logging in via SSH, you can install your GitHub user's SSH key. (optional)
    1. Install OpenSSH server: **YES**
    1. Import SSH identity: **from GitHub**
    1. GitHub username: **[Enter your GitHub username]**

<h3 id="ubuntu">3.2. Ubuntu 20.04.1</h3>

Connect to your VirtualBox machine, assuming the forwarded Host Port is **2200** and the username is **uniphant**:

```sh
ssh -p 2200 uniphant@localhost
```

The following exact step-by-step instructions assume a clean installation of Ubuntu.

```sh
# postgresql:
sudo apt-get -y dist-upgrade
sudo locale-gen "en_US.UTF-8"
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
sudo apt-get -y install gnupg
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql postgresql-server-dev-13 build-essential
# data-checksums is not enabled by default, so let's fix that
sudo sed -i -E "s/^#initdb_options = ''$/initdb_options = '--data-checksums'/" /etc/postgresql-common/createcluster.conf
sudo pg_createcluster 13 with_checksums
sudo systemctl start postgresql@13-with_checksums
sudo -u postgres pg_dumpall --port=5432 --clean | sudo -u postgres psql --port=5433
sudo systemctl stop postgresql@13-main
sudo pg_dropcluster 13 main
sudo systemctl stop postgresql@13-with_checksums
sudo sed -i -E "s/^port = 5433/port = 5432/" /etc/postgresql/13/with_checksums/postgresql.conf
sudo service postgresql start
sudo -u postgres createuser -s "$USER"
createdb -E UTF8 uniphant
createuser api -L
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
```

Installation complete.

You can now try a sign-up using `curl` from the command line:

```sh
curl 'http://localhost/api/rpc/sign_up' \
  -H 'Content-Type: application/json;charset=utf-8' \
  --data '{"username":"test"}' \
  -w "\n"
```

Use `psql` to check the content of the `users` table which should now contain one row:

```sh
psql -x uniphant
```

```sql
SELECT * FROM users;

-[ RECORD 1 ]------+-----------------------------------------------------------------------------------------------------------------------------------
user_id            | 1
user_random_id     | \x4e271a61903586427357f17d4e8e3c1c6a1512a6d6ce3d4de5748c9e15d0bb278e507f0df9911ea5c0d3b7bb159065eb867b5ac68acf92a649c293437fbe3410
username           | test
```

This is how far we get testing in the command line.

To complete a real sign-up and sign-in, we need to use a real browser,
since the private/public key pairs can't be easily generated from the command line,
since they depend on an *Authenticator device*, either built-in TouchID/FaceID,
or an external device like a Yubikey.

To do so, browse to `http://localhost:8080` to test a real sign-up and sign-in.

**Note:** Only works with Chrome and Safari. **Firefox** is currently **not supported** due to a [bug](https://bugzilla.mozilla.org/show_bug.cgi?id=1530370).

<h3 id="certbot">Setting up SSL/TLS using Let's Encrypt/Certbot</h3>

```sh
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --nginx
```

<h3 id="pg_listen">Setting up pg_listen to reload schema automatically</h3>

```sh
# pg_listen:
git clone https://github.com/begriffs/pg_listen.git
cd pg_listen || exit
export PKG_CONFIG_PATH=~/postgresql/src/interfaces/libpq
make
cp pg_listen /usr/local/bin/
cp postgrest-reload-schema.sh /usr/local/bin/
pg_listen postgres://postgrest@/uniphant ddl_command_end $(which postgrest-reload-schema.sh)
```
