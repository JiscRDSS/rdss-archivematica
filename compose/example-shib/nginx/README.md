Shibboleth Example: Nginx Service
==================================

This service provides a "concrete" instance of the [shib/nginx](../shib/nginx) service.

It provides two templated files required by the generic image: the [template nginx config file](etc/nginx/conf.d/example.conf.tpl) and the [template Shibboleth config file](etc/shibboleth/shibboleth2.xml.tpl). The [build script](build.sh) provides these, along with the required private key and certificates signed by the [example CA](../shib/ca).

The nginx server is configured with the required Shibboleth locations, as well as the `/app` location, which is secured by Shibboleth. Through configuration in the `docker-compose` file, this is a proxy to the [myapp](../myapp) application.

By default the nginx service is configured to be available at `https://myapp.example.ac.uk/`.

Building
---------

The [build script](build.sh) will prepare the image with the relevant configuration and certificates etc:

	./build.sh

Configuration
--------------

The template files for the `nginx` configuration and `shibboleth2.xml` configuration are included in the [etc](etc) folder. See [shib/nginx](../../shib/nginx) for more information.
