# Erlangelist

This repository contains the complete source code of [The Erlangelist](http://theerlangelist.com) site:

- [Web site](site/)
- [Articles](site/articles/)
- [Docker images](docker/)
- [Server setup](provisioning/)

## Contributing

If you want to contribute a minor correction to some article (e.g. language and grammar fixes) just make a pull request to the master. If you'd like to make a bigger change, please open a GitHub issue first.

## Running the site locally

Prerequisites:

- Erlang 18
- Elixir 1.1
- PostgreSQL (preferably 9.4)

1. Start the database server on the port 5432.
1. Create the database user `erlangelist` with blank password.
1. Create the database `erlangelist` and grant all privileges to the `erlangelist` user.
1. Go to the `site` folder and fetch `mix` dependencies
1. From the `site` folder start the site with `iex -S mix phoenix.server`

If all went well, the server will listen on the port 20000.

### Running tests

If you want to run tests, you need to create the `erlangelist_test` database, granting all privileges to the `erlangelist` user. Make sure to migrate the database (`MIX_ENV=test mix ecto.migrate`) and then you can start the test.

## Deploying to the production server

__Note:__ Don't deploy to a machine where you run some other system, or which is of some other importance to you. Setup script installs some packages and changes the system configuration (e.g. creates a user, modifies iptables rules, ...).

### Server prerequisites

The target host must run Debian 8 and needs to have `sudo` installed. It also needs the Internet access, because various packages, docker images, and other dependencies are fetched during the initial setup and subsequent deploys.

There is a support available for starting a local Vagrant box that can act as a "staging" server. You need to first run `cd provisioning/vagrant && VM_IP=192.168.54.54 vagrant up` to start the server with a given IP address (feel free to use another IP address).

### Client prerequisites

On your machine you need `bash`, `ansible`, and a `git` client. You also need to configure automatic passwordless ssh login to the server machine (under a login that has sudo privilege).

If you started a local Vagrant box, as explained above, you can run `cd provisioning/vagrant && vagrant ssh-config --host ip_of_the_vm` to get the ssh configuration for your server.

### Filling in the blanks

You need to create the file `site/config/prod_settings.exs` which will contain your secrets (database password and `secret_key_base`). The file should look like:

```elixir
[
  db_password: "super_secret_password",
  secret_key_base: "..."
]
```

You can run `mix phoenix.gen.secret` in the `site` folder to generate the secret key base.

In addition, you need to create `provisioning/git_keys` folder that must contain public keys of all allowed deployers.

### Initial setup

This step installs required packages and sets up the system. You can run `provisioning/setup-server.sh server_ip network_interface`, where network interface is the name of the interface which accepts the requests from the outer world (for example `eth0`).

For example, to set up a local VM with an IP address 192.168.54.54, you can run `provisioning/setup-server.sh 192.168.54.54 eth1`.

### Setting up the git remote

The deploy is performed by pushing to the git repository on the remote server. During the setup, the `git` user is created on the server. You can login as a `git` with any of the keys supplied in `provisioning/git_keys` folder, as explained above.

On your own machine, you need to add something like the following to your ~/.ssh/config:

```
Host 192.168.54.54
  User git
  PreferredAuthentications publickey
  IdentityFile private_key_path
```

In your local git repository, you need to add another remote which will be the deploy target. For example:

```
git remote add local_deploy git@192.168.54.54:erlangelist
```

### Deploying

If all things are properly configured, you can simply deploy the site via

```
git push local_deploy master
```

The first push will run for some time, because it builds all the docker images from scratch. Once everything is done, the site should be listening at the port 80.
