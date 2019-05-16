# rdss-archivematica

Integration repo for the RDSS fork of Archivematica.

## Development Quick Start

For development, you can deploy docker containers into your local Docker environment. Most users will be running as the single user on their system, but multi-user deployments are supported too.

There's now a handy `quickstart` script to get you up and running as quickly as possible. This script will automatically create a unique namespace for each user, as well as selecting ports that are not already in use.

To start up all the required services, volumes and containers etc, use:

	$ ./quickstart start

Once built, you can then check the status with:

	$ ./quickstart status

If you want to terminate your deployment, use:

	$ ./quickstart shutdown

If you no longer want your deployment at all, use:

	$ ./quickstart destroy

This will wipe all persistent data for your deployment and remove any associated built images from your system. Any other deployments on the same Docker environment will remain untouched.

For more advanced usage, see below.

## Usage

This project uses a Makefile to drive the build. Run `make help` to see a list
of targets with descriptions, e.g.:

```
$ make help
build-images                   Build Docker images.
clone                          Clone source code repositories.
help                           Print this help message.
publish                        Publish Docker images to a registry.
```

`publish` expects a `REGISTRY` variable to be defined, e.g.:

    $ make publish REGISTRY=aws_account_id.dkr.ecr.region.amazonaws.com/

To use a local registry, to work with the QA build locally, you can [set up a local Docker registry service](https://docs.docker.com/registry/#basic-commands):

    $ docker run -d -p 5000:5000 --name registry registry:2

You can then use this registry to publish to before doing a compose build:

    $ make publish REGISTRY=localhost:5000/
    $ cd compose
    $ make all REGISTRY=localhost:5000/

You may also want to look at using a [registry frontend](https://github.com/kwk/docker-registry-frontend) to browse your local registry repositories.

## Development environment

Open [the compose folder](compose) to see more details.

## AWS environment

#### Docker Machine + Amazon EC2

Deployment of the development environment in a single EC2 instance supported by Docker Machine.

Open [the aws/machine folder](aws/machine) to see more details.

#### Terraform + Amazon ECS

Using Terraform to create all the necessary infrastructure and Amazon ECS to run the containers in a cluster of EC2 instances.

Open [the aws/ecs folder](aws/ecs) to see more details.

## Requirements

[System requirements][requirements-0]. Memory usage when the environment is
initialized (obtained using `docker stats`):

```
CONTAINER NAME                  MEM USAGE (MiB)
archivematica-mcp-server         60.6
archivematica-mcp-client         32.5
archivematica-dashboard          60.0
archivematica-storage-service    74.6
clamavd                         545.6
gearmand                          1.6
mysql                           530.4
redis                             1.8
nginx                             2.5
elasticsearch                   229.3
fits                             70.7
```

Software dependencies: Docker, Docker Compose, git and make.

It is beyond the scope of this document to explain how these dependencies are
installed in your computer. If you're using Ubuntu 16.04 the following commands
may work:

    $ sudo apt update
    $ sudo apt install -y build-essential python-dev git
    $ sudo pip install -U docker-compose

And install Docker CE following [these instructions][requirements-1].

[requirements-0]: https://www.archivematica.org/docs/latest/getting-started/overview/system-requirements/
[requirements-1]: https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/

Install the `rng-tools` daemon if you want to set up GPG encrypted spaces. The
Storage Service container should have access to the `/dev/random` device.

### Docker and Linux

Docker will provide instructions on how to use it as a non-root user. This may
not be desirable for all.

    If you would like to use Docker as a non-root user, you should now consider
    adding your user to the "docker" group with something like:

      sudo usermod -aG docker <user>

    Remember that you will have to log out and back in for this to take effect!

    WARNING: Adding a user to the "docker" group will grant the ability to run
             containers which can be used to obtain root privileges on the
             docker host.
             Refer to https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface
             for more information.

The impact to those following this recipe is that any of the commands below
which call Docker will need to be run as a root user using 'sudo'.

### Docker and Mac

Installation of Archivematica on machines running macOS using Docker is
possible, but still in development and may require some extra steps. If you are
new to Archivematica and/or Docker, or have an older machine, it may be better
to instead use a Linux machine.

### Elasticsearch container

For the Elasticsearch container to run properly, you may need to increase the
maximum virtual memory address space `vm.max_map_count` to at least `[262144]`.
This is a configuration setting on the host machine running Docker, not the
container itself.

To make this change:

`sudo sysctl -w vm.max_map_count=262144`

To persist this setting, modify `/etc/sysctl.conf` and add:
`vm.max_map_count=262144`

For more information, please consult the Elasticsearch `6.x`
[documentation][documentation-0].

[documentation-0]: https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
