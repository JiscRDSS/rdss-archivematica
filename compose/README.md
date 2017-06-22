Docker-Compose Services
========================

We use `docker-compose` to orchestrate multiple services so that together they combine to provide Archivematica and supporting services, such as database backend, authentication, etc.

The following diagram gives an overview of the deployed service containers, grouped together to show how they are related logically.

![containers diagram](doc/images/containers.jpg)

In the above, the main Archivematica services are highlighted in orange. The services related to Shibboleth are in green, whilst the RDSS-specific containers are highlighted in purple. The nginx service that fronts it all is highlighted in blue. Where relevant the components deployed into each container are shown; for base services this is omitted.

Some of these containers are required for local development only. In a production deployment, the `dynalite`, `minikine` and `minio` containers would be replaced with connections to actual DynamoDB, Kinesis and S3 services in an AWS environment. Similarly, if the Shibboleth SP in the `nginx` container is configured to use an external IdP then the `idp` and `ldap` containers would become unnecessary.

External Volumes
-----------------

To allow Archivematica to interact and share data with other systems in the environment, some volumes are marked as `external`. These must be created prior to starting the docker containers.

| Volume | Description |
|---|---|
| `archivematica_pipeline_data` | Used to store data shared across Archivematica components. Also used by external systems to input data to Archivematica, and to retrieve outputs from Archivematica (`www/AIPsStore` and `www/DIPsStore`). |
| `archivematica_storage_service_default_location_data` | Used to provide data storage for the Storage Service. Making this external allows other systems to input data into Archivematica. |

To create volumes for directories on the local machine, i.e. in a development environment, use

	make create-local-volumes

To create volumes for directories on a NFS server, i.e. in a QA or production environment, use

	make create-nfs-volumes NFS_SERVER=192.168.0.1

The `NFS_SERVER` is required - there's no way to guess it or use a sensible default.

The parameters for the volumes created are as follows, and may be overridden via Makefile arguments:

| Parameter | Description | Default |
|---|---|---|
| `AM_PIPELINE_DATA` | The *local* path on the docker host to use for Archivematica's `sharedDirectory` pipeline data. | `$(BASE_DIR)/vols/am-pipeline-data`
| `SS_DEFAULT_LOCATION_DATA` | The *local* path on the docker host to use for Archivematica's default location in the Storage Service. | `$(BASE_DIR)/../src` |
| `NFS_SERVER` | The IP address of the NFS server to use for the NFS volumes. This value is required. | N/A |
| `NFS_AM_PIPELINE_DATA` | The *remote* path on the NFS server to use for Archivematica's `sharedDirectory` pipeline data. | `/am-pipeline-data` |
| `NFS_SS_DEFAULT_LOCATION_DATA` | The *remote* path on the NFS server to use for Archivematica's default location in the Storage Service. |

Service Sets
-------------

There are currently three service sets defined:

1. [dev](dev), which defines the main Archivematica services and supporting web server, db, etc, suitable for use in a development environment.
1. [am-shib](am-shib), which wraps the Archivematica services in the [dev](dev) service set in Shibboleth authentication.
1. [shib-local](shib-local), which provides a local example Shibboleth IdP with backing LDAP directory.

These service sets are defined by [docker-compose.dev.yml](docker-compose.dev.yml), [docker-compose.am-shib.yml](docker-compose.am-shib.yml), and [docker-compose.shib-local.yml](docker-compose.shib-local.yml) respectively. You can use the [COMPOSE_FILE](https://docs.docker.com/compose/reference/envvars/) environment variable to set which `docker-compose` file or files you wish to use.

To just configure the Archivematica dev environment, use

	COMPOSE_FILE=docker-compose.dev.yml docker-compose <compose-args>

To configure Archivematica with local Shibboleth authentication, use

	COMPOSE_FILE=docker-compose.dev.yml:docker-compose.am-shib.yml:docker-compose.shib-local.yml docker-compose \
		<compose-args>

To configure Archivematica with external Shibboleth authentication, use

	SHIBBOLETH_IDP_ENTITY_ID=https://your.domain/idp/shibboleth \
	SHIBBOLETH_IDP_METADATA_URL=https://your.domain/path/to/idp/metadata \
	COMPOSE_FILE=docker-compose.dev.yml:docker-compose.am-shib.yml:docker-compose.shib-local.yml docker-compose \
		<compose-args>

This is quite a mouthful, so there are also Makefiles defined that shortcut some of this for you, for example:

	make all SHIBBOLETH_CONFIG=archivematica

This will set `COMPOSE_FILE=docker-compose.dev.yml:docker-compose.am-shib.yml:docker-compose.shib-local.yml` when calling `docker-compose` as part of the build process. To use an external IdP with the `make` command:

	SHIBBOLETH_IDP_ENTITY_ID=https://your.domain/idp/shibboleth \
	SHIBBOLETH_IDP_METADATA_URL=https://your.domain/path/to/idp/metadata \
		make all SHIBBOLETH_CONFIG=archivematica SHIBBOLETH_IDP=external

In future we may make this easier by adding specific support for certain IdPs, for example UKAMF.

In general it is recommended to use the `make` commands rather than call `docker-compose` directly for building, as there are a number of additional tasks that need to be done other than `docker-compose build`.

The exception to this is when using existing container instances. For example:

	COMPOSE_FILE=docker-compose.dev.yml:docker-compose.am-shib.yml docker-compose up -d --force-recreate --no-deps nginx

This will set the right `COMPOSE_FILE` context whilst allowing you to redeploy the `nginx` service, without having to do a full teardown-and-rebuild that `make all` would do.

Service Details
----------------

Details of the services deployed for each service set are in the README for that service set.

* [Archivematica Services](dev/README.md)
* [Shibboleth-enabled Archivematica Services](am-shib/README.md)
* [Local Shibboleth IdP Service](shib-local/README.md)

Building
---------

*Before building, make sure you create the required volumes (see above)*

To build all containers required to bring up a development version of Archivematica, use

	make all

This will create all the services defined in [docker-compose.dev.yml](docker-compose.dev.yml), which is symlinked by [docker-compose.yml](docker-compose.yml). There is no Shibboleth integration in this usage, so if you're not interested in Shibboleth, use this.

To enable Shibboleth integration, use

	make all SHIBBOLETH_CONFIG=archivematica

This will include additional services defined in [docker-compose.am-shib.yml](docker-compose.am-shib.yml) in addition to those in [docker-compose.dev.yml](docker-compose.dev.yml).

By default this will include the local example Shibboleth IdP in [docker-compose.shib-local.yml](docker-compose.shib-local.yml) too. In future it may be possible to define a different Shibboleth IdP using the `SHIBBOLETH_IDP` environment variable (e.g. to use the UKAMF or UKAMF test IdPs). Alternatively, the `SHIBBOLETH_IDP_ENTITY_ID` and `SHIBBOLETH_IDP_METADATA_URL` environment variables may be used to override this. To use an alternative IdP and prevent the local IdP from being created, use `SHIBBOLETH_IDP=false`.

After a successful build of the Shibboleth-enabled Archivematica services you should find you have the following services listed by `make list`:

	              Name                             Command                             State                              Ports
	-----------------------------------------------------------------------------------------------------------------------------------------
	archivematica.example.ac.uk        /usr/local/bin/ep -v /etc/ ...     Up                                 0.0.0.0:443->443/tcp,
	                                                                                                         0.0.0.0:34312->80/tcp,
	                                                                                                         0.0.0.0:34311->8000/tcp,
	                                                                                                         0.0.0.0:8443->8443/tcp, 9090/tcp
	idp.example.ac.uk                  /bin/sh -c bootstrap.sh && ...     Up                                 0.0.0.0:6443->4443/tcp, 8443/tcp
	rdss_archivematica-dashboard_1     /bin/sh -c /usr/local/bin/ ...     Up                                 8000/tcp
	rdss_archivematica-mcp-client_1    /bin/sh -c /src/MCPClient/ ...     Up
	rdss_archivematica-mcp-server_1    /bin/sh -c /src/MCPServer/ ...     Up
	rdss_archivematica-storage-        /bin/sh -c /usr/local/bin/ ...     Up                                 8000/tcp
	service_1
	rdss_clamavd_1                     /run.sh                            Up                                 3310/tcp
	rdss_dynalite_1                    node ./dynalite.js                 Up                                 0.0.0.0:34306->4567/tcp
	rdss_elasticsearch_1               /docker-entrypoint.sh elas ...     Up                                 9200/tcp, 9300/tcp
	rdss_fits_1                        /usr/bin/fits-ngserver.sh  ...     Up                                 2113/tcp
	rdss_gearmand_1                    docker-entrypoint.sh --que ...     Up                                 4730/tcp
	rdss_ldap_1                        /container/tool/run                Up                                 389/tcp, 636/tcp
	rdss_minikine_1                    node ./minikine.js                 Up                                 0.0.0.0:34307->4567/tcp
	rdss_minio_1                       /usr/bin/docker-entrypoint ...     Up                                 0.0.0.0:34305->9000/tcp
	rdss_mysql_1                       docker-entrypoint.sh mysqld        Up                                 3306/tcp
	rdss_rdss-archivematica-channel-   go run main.go consumer            Up                                 0.0.0.0:34314->6060/tcp
	adapter-consumer_1
	rdss_rdss-archivematica-channel-   go run main.go publisher           Up                                 0.0.0.0:33786->6060/tcp
	adapter-publisher_1
	rdss_rdss-archivematica-           go run main.go -addr=0.0.0 ...     Up                                 0.0.0.0:34308->8000/tcp
	msgcreator_1
	rdss_redis_1                       docker-entrypoint.sh --sav ...     Up                                 6379/tcp

Notice that the `idp.example.ac.uk`,  and `archivematica.example.ac.uk` have specific ports exposed - this is because Shibboleth requires well-known URLs for the Service Provider and Identity Provider.

If you wish to change the ports used to something other than the default then you can change them using the environment variables defined in the [.env](.env) file in this folder, which is used by `docker-compose` during the build, or by overriding them via environment variables:

	NGINX_EXTERNAL_PORT=3443 make all SHIBBOLETH_CONFIG=archivematica

You can also change the domain name, by setting the `DOMAIN_NAME` environment variable. This can be done in the [.env](.env) file, or on the command line:

	DOMAIN_NAME=my.edu make all SHIBBOLETH_CONFIG=archivematica

The above would cause all containers and services to use the `my.edu` domain instead, including LDAP records and SSL certificates. Remember to update `/etc/hosts` on the docker host if you used the example entries above, so that the domain names in the FQDN match too.

Other Commands
---------------

Here are some other `make` commands other than `make all` that may be useful when working with these`docker-compose` configurations. These are designed to make it easier to ensure that the right context is available when using multiple configurations, such as when running with `SHIBBOLETH_CONFIG=archivematica`.

| Command | Description |
|---|---|
| `make clean` | Remove all build-generated files. |
| `make destroy` | Tear down all running containers for the configured compose set. |
| `make list` | List all running containers (using `docker-compose ps`) |
| `make watch` | Watch logs from all containers |
| `make watch-idp` | Watch logs from the [idp](shib-local/idp) container, if present |
| `make watch-idp` | Watch logs from the `nginx` container |


Remember to append the `SHIBBOLETH_CONFIG` argument to the above commands if `make all` was run with this set, otherwise the `docker-compose` context won't be resolved properly (this is required for the `watch-idp` command).

Environment Variables
----------------------

The following environment variables are supported by this build.

| Variable | Description |
|---|---|
| `AM_PIPELINE_DATA_VOLUME` | The named Docker volume to use for Archivematica pipeline data. This is an external volume that is expected to be created prior to the containers being instantiated (see [External Volumes](#externalvolumes) above). Valid values are `local_am-pipeline-data` (default) or `nfs_am-pipeline-data`. |
| `DOMAIN_NAME` | The domain name to use when configuring Shibboleth. |
| `SHIBBOLETH_CONFIG` | The Shibboleth profile to use. Currently only `archivematica` is supported. Default is undefined, causing no Shibboleth support to be enabled. |
| `SHIBBOLETH_IDP` | The shibboleth IdP profile to use. Currently only `local` is supported, which is the default if `SHIBBOLETH_CONFIG` is set. Setting to another value will prevent the local Shibboleth IdP ([shib-local](shib-local)) from being included. |
| `SS_DEFAULT_LOCATION_DATA_VOLUME` | The named Docker volume to use for Archivematica Storage Service default location data. This is an external volume that is expected to be created prior to the containers being instantiated (see [External Volumes](#externalvolumes) above). Valid values are `local_ss-default-location-data` (default) or `nfs_ss-default-location-data`. |
| `VOL_BASE` | The path to use as the base for specifying volume paths in `docker-compose` configurations. Default is `'.'`, which gets correctly interpreted when build machine is the same as docker host. When deploying to a remote docker host (e.g. via `docker-machine`), this must be set to the path of the equivalent base path on the docker host, e.g. `/home/ubuntu/rdss-archivematica/compose` if using a standard Ubuntu AMI on EC2). |

See also the individual [idp](shib-local/idp), [ldap](shib-local/ldap) and [nginx](am-shib/nginx) services for additional environment variables used by those specific services.

Secrets
--------

Some of the configuration of these services may be considered "secret", i.e. data that should't be committed to a source control system. This includes, but is not limited to, key and certificate files used by SSL and Shibboleth services to secure and verify connections and communication.

These secrets are created by the `create-secrets.sh` script in the relevant folder for each service. This script is run as part of the `make` build process.

Currently they are stored as normal files and mounted to the `/secrets` directory within each service container, but in future this may change to use the [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/) functionality, or its equivalent for other platforms (e.g. [Vault](https://www.vaultproject.io/) for AWS deployment).
