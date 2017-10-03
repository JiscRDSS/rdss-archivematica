NextCloud Service
==================

The containers in this `docker-compose` service set provide an instance of [NextCloud](https://nextcloud.com/) to enable data to be transferred in and out of the Arkivum/Archivematica preservation service, and within the service between different Archivematica and Arkivum components.

The service is very simple, consisting of just `nextcloud` and `mysql` services. The `nextcloud` service uses the [`arkivum/rdss-nextcloud`](https://github.com/JiscRDSS/rdss-arkivum-nextcloud) image.

By default this service is available on port 8888.

Building
---------

This service is intended to be used alongside the main Archivematica services, but can be used independently if necessary.

To build as part of a larger `docker-compose` set, use the parent [compose](compose) makefile, with the `NEXTCLOUD_ENABLED=true` parameter. To build standalone, use:

	COMPOSE_FILE=docker-compose.nextcloud.yml docker-compose build

This will build all of the required containers, including `mysql`.

The [makefile](Makefile) includes a `build` goal which ensures the files-move app is built. This uses the `build-files-move-app` goal in the source project's makefile.

Environment Variables
-----------------------

The following variables may be used to override default configuration settings.

| Variable | Description | Default |
|---|---|---|
| `NEXTCLOUD_EXTERNAL_IP` | The external IP that the NextCloud service should be available on. | `0.0.0.0` |
| `NEXTCLOUD_EXTERNAL_PORT` | The external port that the NextCloud service should be available on. | `8888` |
| `NEXTCLOUD_RUNAS_GID` | The group id of the user to run NextCloud as. | 991 |
| `NEXTCLOUD_RUNAS_UID` | The user id of the user to run NextCloud as. | 991 |

There are additional environment variables, which are [defined by the NextCloud image](https://github.com/JiscRDSS/rdss-arkivum-nextcloud).
