Docker Services for Archivematica and NextCloud
================================================

The containers in this `docker-compose` service set provide an instance of [Archivematica](https://www.archivematica.org) and an instance of [NextCloud](https://nextcloud.com/) to enable data to be transferred in and out of the Arkivum/Archivematica preservation service, and within the service between different Archivematica and Arkivum components.

The Archivematica services use the Docker images defined within the [archivematica](https://github.com/JiscRDSS/archivematica) and [archivematica-storage-service](https://github.com/JiscRDSS/archivematica-storage-service) projects. The NextCloud service uses the Docker image defined by [rdss-arkivum-nextcloud]((https://github.com/JiscRDSS/rdss-arkivum-nextcloud).

Download the sources
---------------------

Go to the root folder of this repository and run `make clone`.

Build the environment
----------------------

First we need to build the custom apps we install for NextCloud.

    $ make build-nextcloud-apps

Then we can build the services. This step may take a while because we're building multiple Docker images with the Archivematica dependencies.

    $ docker-compose build

Start everything:

    $ docker-compose up -d

We need to bootstrap the system:

    $ make bootstrap

List the containers running:

    $ docker-compose ps

You should see something like the following:

```
$ docker-compose ps
               Name                              Command               State                            Ports
--------------------------------------------------------------------------------------------------------------------------------------
dev_archivematica-dashboard_1         /bin/sh -c /usr/local/bin/ ...   Up      8000/tcp
dev_archivematica-mcp-client_1        /bin/sh -c /src/MCPClient/ ...   Up
dev_archivematica-mcp-server_1        /bin/sh -c /src/MCPServer/ ...   Up
dev_archivematica-storage-service_1   /bin/sh -c /usr/local/bin/ ...   Up      8000/tcp
dev_clamavd_1                         /run.sh                          Up      3310/tcp
dev_elasticsearch_1                   /docker-entrypoint.sh elas ...   Up      9200/tcp, 9300/tcp
dev_gearmand_1                        docker-entrypoint.sh --que ...   Up      4730/tcp
dev_mysql_1                           docker-entrypoint.sh mysqld      Up      3306/tcp
dev_nginx_1                           nginx -g daemon off;             Up      443/tcp, 0.0.0.0:32821->80/tcp, 0.0.0.0:32820->8000/tcp
dev_redis_1                           docker-entrypoint.sh --sav ...   Up      6379/tcp
```

Nginx is the web frontend and you can use it to access Archivematica. The `Ports` column shows which ports have been made available. Based on the example above, open your browser and point to:

- http://127.0.0.1:32821 (Archivematica Dashboard)
- http://127.0.0.1:32820 (Archivematica Storage Service)

The ports assigned are not permament.

Once you're done you can destroy everything with: `make destroy`. This task will also remove the data volumes, e.g. the changes written to disk (like those belonging in a database) will also be lost permanently.

Proceeding with the installer
------------------------------

Log in the Storage Service first using the default user: `test`, password `test`. Go to the user page under the *Administration* area to find your API key. Next, open the dashboard. You will need the API key when you're requested to introduce the connection details of the Storage Service.

Development workflow
---------------------

If your working on webapps like `dashboard` or `archivematica-storage-service` your changes in the source code should take effect immediately - you don't need to restart the service. But in some cases you also need to regenerate the container (e.g. if you change parameters in `docker-compose.dev.yml`). A nice shortcut that can do that for you while making sure the service is started again is:

    $ docker-compose up -d archivematica-dashboard

If you add the `--build` flag, the Docker image will be rebuilt too. This is useful when you've made changes to the `Dockerfile` or perhaps added new dependencies to `requirements/*.txt` that you want to be installed. For example:

    $ docker-compose up --build -d archivematica-dashboard

In some cases you need to go further and discard any image layer cached previously. You can only do this using `docker-compose build` directly:

    $ docker-compose build --no-cache --pull archivematica-dashboard

Our containers send log events to `stderr` by default. You can watch the output using `docker-compose logs`. Use the `-f` argument to follow the log output.

### Using django-admin

django-admin is Django's command-line utility for administrative tasks. One of its most interesting features is the interactive interpreter, e.g. the following opens a new shell in the Dashboard:

    $ docker-compose run --rm --entrypoint=/src/dashboard/src/manage.py archivematica-dashboard shell

Similary, you can open a shell in the Storage Service with:

    $ docker-compose run --rm --entrypoint=/src/storage_service/manage.py archivematica-storage-service shell

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
