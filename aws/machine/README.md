# Deployment with Docker Machine into Amazon Web Services

## Introduction

This document describes the process needed to install the RDSSARK solution into EC2 instances using Docker Machine and the AWS CLI.

It is a replica of the development environment. This is not intended for use in production but is suitable for QA use.

## Requirements

The following software is required to be installed to run a deployment:

- [Docker Engine](https://docs.docker.com/engine/)
- [Docker Compose](https://docs.docker.com/compose/overview/)
- [Docker Machine](https://docs.docker.com/machine/overview/)

[Docker for Windows](https://docs.docker.com/docker-for-windows/) or [Docker for Mac](https://docs.docker.com/docker-for-mac/) include all the tools needed.

If you are a Linux user you need to install them [separately](https://docs.docker.com/manuals/).

However, before attempting any deployment you will need the following:

1. Access to an AWS account (root or IAM credentials are fine)
1. A pre-existing VPC configured in which to deploy to
1. A pre-existing subnet within the VPC in which to deploy to
1. Ideally, a pre-existing registered domain that you have DNS management access for.

If you do not have access to a registered domain then you can use "poor man's" DNS by editing and maintaining your `/etc/hosts` manually.

## AWS credentials

The easiest way to configure credentials is to use the standard credential file `/.aws/credentials`, which might look like:

    [default]
    aws_access_key_id = MY-ACCESS-KEY-ID
    aws_secret_access_key = MY-SECRET-KEY

Also, create a new SSH key pair:

    $ ssh-keygen -f ~/.ssh/id_rsa_MyAwsKey -t rsa -b 4096 -N ''

## Provisioning and Deployment

The [deploy](deploy.sh) script will automatically provision EC2 instances for an Arkivum appliance, a NFS server and a Docker host. The Docker host is provisioned using `docker-machine`, other instances and resources are provisioned using the AWS CLI tool. As well as provisioning, the deploy script also builds Docker images and mounts volumes to allow services to integrate and interact. The Docker deployment uses Docker Compose services (defined [here](../../compose)) for instantiation.

Before use, you will need to fill out the [configuration template](etc/deployment.conf.template) and save it to `etc/deployment.conf`. This template file requires that you fill in parameters relating to a) your AWS account, and b) the environment you wish to deploy.

### AWS Account Parameters

1. `MFA_AUTH_ENABLED`: Whether or not to require an MFA device for authentication
1. `MFA_DEVICE_ID`: The ARN of your MFA device, as shown in the IAM console
1. `VPC_ID`: The ID of the Virtual Private Cloud to deploy instances into
1. `SUBNET_ID`: The ID of the subnet to deploy instances into
1. `PUBLIC_DOMAIN_NAME`: The name of the public DNS domain to use for the deployment. This domain must be under your control, as you will need to update the nameserver information to point to the Route53 nameservers Amazon provides.

### Deployment Parameters

1. `SSH_KEY_PATH`: The path of the RSA key to use to secure SSH access to deployed instances
1. `PROJECT_ID`: The id for this deployment, for example `235`
1. `ENVIRONMENT`: The environment for the deployment - one of `dev`, `uat` or `prod`
1. `RDSSARK_VERSION`: The branch of the `rdss-archivematica` project to deploy. This may be a version tag, e.g. `v0.2.0`. Default is `master`.

### Arkivum Appliance Parameters

1. `ARKIVUM_ENABLED`: Whether or not to include an Arkivum appliance in the deployment. A non-empty value will cause the appliance to be deployed, empty value will be evaluated as false. Defaults to `""`, i.e. disabled.
1. `ARKIVUM_INSTANCE_TYPE`: The EC2 instance type to use for the Arkivum appliance. Defaults to `t2.nano` so most deployments will want to change this.

### Docker Host Parameters

1. `DOCKERHOST_INSTANCE_TYPE`: The EC2 instance type to use for the Docker host. Defaults to `t2.medium`, which is the minimum required for all containers to build and run.
1. `DOCKERHOST_ROOT_SIZE`: The size of the root partition for the Docker host, in gigabytes. Defaults to 16, which is the minimum viable for running all containers.

### NextCloud Parameters

1. `S3_BUCKET_PARAMS`: The parameters of the S3 bucket that you wish to mount into NextCloud

### NFS Server Parameters

1. `NFS_INSTANCE_TYPE`: The EC2 instance type to use for the NFS server. Defaults to `t2.nano` so most deployments will want to change this.
1. `NFS_STORAGE_SIZE`: The size of the EBS volume to provision for use by the NFS server for storage, in GB. Default is `10`, so most deployments will want to change this.
1. `NFS_STORAGE_VOLUME_TYPE`: Volume type of the EBS volume for use by the NFS server for storage. Defaults to `gp2`, so if you're using a size larger than 500GB then you should change this to `st1' or 'sc1'.

### Application Security Parameters

1. `DOMAIN_ORGANISATION`: The name of the organisation that this deployment is for. This is used for SSL certificates and also Shibboleth configuration, if enabled. Defaults to "Example University".
1. `SHIBBOLETH_CONFIG`: Which Shibboleth config to use, if any. Default is `archivematica`. Set to `none` to disable Shibboleth.

Additional parameters are also available, but the defaults for these are generally okay. See the comments in the [configuration template](etc/deployment.conf.template) for details.

Once you have created your config file, you can run the script:

    ./deploy.sh

This script will take care of any necessary authentication with AWS, and will challenge you for an MFA code if required.

If you wish to override some or all configuration options using environment variables then you can, for example:

    PUBLIC_DOMAIN_NAME=mydomain.net PROJECT_ID=1234 ./deploy.sh

Again, see the [configuration template](etc/deployment.conf.template) for the full list of settings that can be overriden.

## Connecting to Deployed Services

The deployment script will output the public IP addresses for each of the Arkivum appliance, NFS server and Docker host instances that have been deployed for the configured project id and environment.

These IP addresses are automatically associated with DNS hosted zones in AWS Route53. The `deploy` script will output the host names for each instance as well as the URLs that the deployed services are available on.

## Tearing Down

To tear down resources, use the [teardown.sh](teardown.sh) script:

    ./teardown.sh

Like the deploy script, this will also read the config defined in `etc/deployment.conf`. You can also override any of the settings defined in this config:

    PUBLIC_DOMAIN_NAME=mydomain.net PROJECT_ID=1234 ./teardown.sh

By default the teardown script **will not** remove EBS volumes that are not set to be deleted when an instance terminates. In particular, the data volume used by the NFS server will not be deleted. To override this, use the `DESTROY_VOLUMES` environment variable:

    PUBLIC_DOMAIN_NAME=mydomain.net DESTROY_VOLUMES=yes PROJECT_ID=1234 ./teardown.sh

**WARNING: ALL DATA FOR THE GIVEN `PROJECT_ID` AND `ENVIRONMENT` WILL BE DESTROYED BY THIS COMMAND!!**

# Known Issues / TODO

1. Arkivum appliance instance is currently not installed properly, so won't work
1. SSL certificates are currently self-signed so will generate warnings when HTTPS resources are accessed
1. Instances and containers do not use private zone for DNS (currently use AWS default instead, so full host name need to be given to resolve)
1. Should probably aim to use Ansible for some/most/all of this deployment process
1. Not tested on anything other than Ubuntu 14.04
1. It should be possible to deploy without assuming the use of a registered public domain name
