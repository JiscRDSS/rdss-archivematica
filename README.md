# rdss-archivematica

Integration repo for the RDSS fork of Archivematica.

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
