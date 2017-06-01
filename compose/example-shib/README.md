Shibboleth Example
===================

The containers in this `docker-compose` service set implement a full Shibboleth environment, including an example IdP (backed by an example LDAP service), two SPs and a secured demo application hosted in nginx.

It does not make any reference to Archivematica; it is purely to demonstrate Shibboleth and its integration with nginx and Django, using some simple Django-based applications.

Methodology
------------

For each service, an existing Docker image was sought from the Docker Hub registry, and these were used as a basis for the service containers. However, none of these were suitable for use "out of the box", and several required additional configuration prior to the image being built.

The build process for each service container therefore has three steps:

1. Prepare the build, downloading source files as appropriate and running setup tasks to generate configuration for inclusion in the image.
1. Use `docker-compose build` to build the Dockerfile images
1. Use `docker-compose exec` and `docker-compose run` to "bootstrap" the containers by doing post-start configuration, such as populating the LDAP directory.

Services
---------

### Nginx (with Shibboleth SP)

The `nginx` container uses the `arkivum/shibboleth-nginx` image, which is built using the "abstract" `shib/nginx` [Dockerfile](../shib/nginx/Dockerfile). This is prepared and built using the [build script](nginx/build.sh).

See the [README](nginx/README.md) for more details.

### Shibboleth IdP

This container uses the `arkivum/shibboleth-idp` image, which is built using the "abstract" `shib/idp` [Dockerfile](../shib/idp/Dockerfile). This is prepared and built using its [build script](idp/build.sh).

See the [README](idp/README.md) for more details.

### Shibboleth SP1

This container runs the [sp1](https://github.com/serglopatin/sp1) application to demonstrate the use of the [djangosaml2]() library to interact with a Shibboleth IdP. This is an alternative to using the Shibboleth SP FastCGI module used in the `nginx` container.

See the [README](sp/README.md) for more details.

### MyApp

This container runs a very simple Django application. It does not offer any Shibboleth integration itself - instead it expects to be protected by Shibboleth via the nginx container, which is expected to be used as a proxy layer for this service.

See the [README](myapp/README.md) for more details.
