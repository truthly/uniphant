<h1 id="top">🦄🐘<code>uniphant</code></h1>

<p align="left">
  <a href="https://github.com/truthly/uniphant/actions"><img alt="build-test status" src="https://github.com/truthly/uniphant/workflows/build-test/badge.svg"></a>
  <a href="https://github.com/truthly/uniphant/actions"><img alt="super-linter status" src="https://github.com/truthly/uniphant/workflows/super-linter/badge.svg"></a>  
</p>

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
1. To simplify logging in via SSH, you can install your GitHub user's SSH key. (optional)
    1. Install OpenSSH server: **YES**
    1. Import SSH identity: **from GitHub**
    1. GitHub username: **[Enter your GitHub username]**

<h3 id="installation-osx">3.2. Ubuntu 20.04.1</h3>

The following exact step-by-step instructions assume a clean installation of Ubuntu.

```sh
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
(cd pg-ecdsa && PG_CFLAGS="-Wno-vla -Wno-declaration-after-statement -Wno-missing-prototypes" make && sudo make install && make installcheck)
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
```

Installation complete.

You can now try to initiate a sign-up using `curl` from the command line:

```sh
curl 'http://localhost/api/rpc/init_credential' \
  -H 'Content-Type: application/json;charset=utf-8' \
  --data '{"username":"test","display_name":"Test User"}' \
  -w "\n"
```

If everything is OK, you should see output that looks like this:

```json
{"publicKey": {"rp": {"name": "ACME Corporation"}, "user": {"id": "mxgsmiTKowofNg71mxPYxq4QX_YmzfQpX6bvrMnfC91AlzIh6L663p9rBqGKK5fOWjHrcriupYlMg2F4pWjujg", "name": "test", "displayName": "Test User"}, "timeout": 300000, "challenge": "Y3SLvrDyb42jNV6JRwr_XGsqN35gk-WEXdzWAKKZCOQ", "attestation": "none", "pubKeyCredParams": [{"alg": -7, "type": "public-key"}], "authenticatorSelection": {"userVerification": "discouraged", "requireResidentKey": true}}}
```

Use `psql` to check the content of the `webauthn.credential_challenges` table which should now contain one row:

```sh
uniphant@uniphant:~/uniphant$ psql uniphant
psql (13.1 (Ubuntu 13.1-1.pgdg20.04+1))
Type "help" for help.

uniphant=# \x
Expanded display is on.
```

```sql
SELECT * FROM webauthn.credential_challenges

-[ RECORD 1 ]------+-----------------------------------------------------------------------------------------------------------------------------------
challenge          | \x63748bbeb0f26f8da3355e89470aff5c6b2a377e6093e5845ddcd600a29908e4
user_name          | test
user_id            | \x9b182c9a24caa30a1f360ef59b13d8c6ae105ff626cdf4295fa6efacc9df0bdd40973221e8bebade9f6b06a18a2b97ce5a31eb72b8aea5894c836178a568ee8e
user_display_name  | Test User
relying_party_name | ACME Corporation
relying_party_id   |
user_verification  | discouraged
attestation        | none
timeout            | 00:05:00
challenge_at       | 2020-12-26 12:23:57.560249+01
```

This is how far we get testing in the command line.

To complete a real sign-up and sign-in, we need to use a real browser,
since the private/public key pairs can't be easily generated from the command line,
since they depend on an *Authenticator device*, either built-in TouchID/FaceID,
or an external device like a Yubikey.

To do so, browse to `http://localhost:8080` to test a real sign-up and sign-in.

**Note:** Only works with Chrome and Safari. **Firefox** is currently **not supported** due to a [bug](https://bugzilla.mozilla.org/show_bug.cgi?id=1530370).

After sign-in and sign-up, you will see the new user in the `users` table and the generated token in the `tokens` table.

```sh
uniphant@uniphant:~/uniphant$ psql uniphant
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
