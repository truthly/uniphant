<h1 id="top">🦄🐘<code>uniphant</code></h1>

1. [About](#about)
2. [Dependencies](#dependencies)
3. [Installation](#installation)

<h2 id="about">1. About</h2>

`uniphant` is

<h2 id="dependencies">2. Dependencies</h2>

[pg-webauthn](https://github.com/truthly/pg-webauthn) for the WebAuthn Server.

[PostgREST](https://postgrest.org/en/v7.0.0/) for the API.

<h2 id="installation">3. Installation</h2>

<h3 id="installation-osx">3.1. Running Ubuntu in VirtualBox</h3>

1. Download and install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
1. Download [Ubuntu 20.04.1 ISO](https://releases.ubuntu.com/20.04/ubuntu-20.04.1-live-server-amd64.iso)
1. Open VirtualBox
1. Click **New** and follow instructions
1. Click **Settings** and goto **Network**, change to **Bridged Adapter**
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

Next, you need to forward a port from your local machine to the Linux server.
Replace **uniphant** with your usernmae and **192.168.1.153** with your Linux server IP.

```sh
ssh -L 8080:127.0.0.1:80 uniphant@192.168.1.153
```

Next, you can connect with a browser to `http://localhost:8080` and test sign-up and sign-in.
