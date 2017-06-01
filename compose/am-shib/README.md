Shibboleth-enabled Archivematica Services
===========================================

The containers in this `docker-compose` service set provide an Archivematica deployment that uses Shibboleth authentication to secure access.

Building
---------

Use `make` to build these services:

	make all

Though the above can be used, it will not include any of the main Archivematica containers, so the `nginx` service will not have any running services to proxy. Because of this, it is recommended you use the parent [compose](compose) makefile to build this service set, unless wishing to reduce the build time during development/debugging.

Services
---------

In addition to the main Archivematica containers, this service set includes the following services.

### Nginx (with Shibboleth SP)

This container overrides the `dev/nginx` container and uses the `arkivum/shibboleth-nginx` image, which is built using the "abstract" `shib/nginx` [Dockerfile](../shib/nginx/Dockerfile). It proxies the Archivematica Dashboard and Storage Service, using the Shibboleth SP to secure access to these resources.

See the [README](nginx/README.md) for more details.

### Shibboleth IdP

This container uses the `arkivum/shibboleth-idp` image, which is built using the "abstract" `shib/idp` [Dockerfile](../shib/idp/Dockerfile). This is prepared and built using its [build script](idp/build.sh).

See the idp [README](idp/README.md) for more details.
