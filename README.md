![Build Status](https://github.com/sasa1977/erlangelist/workflows/erlangelist/badge.svg)

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

Erlang, Elixir, and node.js. See [./.tool-versions] for exact versions. You can also use [asdf version manager](https://github.com/asdf-vm/asdf) to install these prerequisites.

Starting:

```
cd site
mix deps.get
pushd assets && npm install && popd
iex -S mix phx.server
```

If all went well, the server will listen on ports 20080 (http) and 20443 (https).

## Deploying to the production server

__Note:__ Don't deploy to a machine where you run some other system, or which is of some other importance to you. Setup script installs some packages and changes the system configuration (e.g. creates a user, modifies iptables rules, ...).

### Server prerequisites

The target host must run Debian 8 and needs to have `sudo` installed. It also needs the Internet access, because various packages, docker images, and other dependencies are fetched during the initial setup and subsequent deploys.

There is a support available for starting a local Vagrant box that can act as a "staging" server. You need to first run `cd provisioning/vagrant && VM_IP=192.168.54.54 vagrant up` to start the server with a given IP address (feel free to use another IP address).

### Client prerequisites

On your machine you need `bash`, `ansible`, and a `git` client. You also need to configure automatic passwordless ssh login to the server machine (under a login that has sudo privilege).

If you started a local Vagrant box, as explained above, you can run `cd provisioning/vagrant && vagrant ssh-config --host ip_of_the_vm` to get the ssh configuration for your server.

### Filling in the blanks

You need to create `provisioning/git_keys` folder that must contain public keys of all allowed deployers.

### Initial setup

This step installs required packages and sets up the system. You can run `provisioning/setup-server.sh server_ip network_interface`, where network interface is the name of the interface which accepts the requests from the outer world (for example `eth0`).

For example, to set up a local VM with an IP address 192.168.54.54, you can run `provisioning/setup-server.sh 192.168.54.54 eth1`.

### Setting up the git remote

The deploy is performed by pushing to the git repository on the remote server. During the setup, the `git` user is created on the server. You can login as a `git` with any of the keys supplied in `provisioning/git_keys` folder, as explained above.

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
