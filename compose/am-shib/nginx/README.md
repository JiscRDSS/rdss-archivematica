Shibboleth-enabled Archivematica: Nginx Service
================================================

This service provides a "concrete" instance of the [shib/nginx](../shib/nginx) service.

It provides two templated files required by the generic image: the [template nginx config file](etc/nginx/conf.d/example.conf.tpl) and the [template Shibboleth config file](etc/shibboleth/shibboleth2.xml.tpl). The [build script](build.sh) provides these, along with the required private key and certificates signed by the [domain CA](../shib/ca).

The nginx service hosts two virtual servers, one for the Archivematica Dashboard on port 443, and one for the Archivematica Storage Service on port 8443. Each server is configured with the required Shibboleth locations, as well as the `/` location, which is secured by Shibboleth. Some resources, such as `/api` and static media are not secured, because they don't need to be.

By default the nginx service is configured to be available at `https://archivematica.example.ac.uk/`.

Building
---------

The [build script](build.sh) will prepare the image with the relevant configuration and certificates etc:

	./build.sh

Configuration
--------------

The template files for the `nginx` configuration and `shibboleth2.xml` configuration are included in the [etc](etc) folder. See [shib/nginx](../../shib/nginx) for more information.

Unlike [example-shib/nginx](../../example-shib/nginx), the Archivematica Shibboleth configuration is a bit more involved and specific.

In particular, it has been tuned to work with the eduPerson schema, which is what the [attribute map](etc/shibboleth/attribute-map.xml) does. The [shibboleth2.xml](etc/shibboleth/shibboleth2.xml.tpl) includes access control elements that restrict access to the Dashboard and Storage Service based on a user's entitlements (derived from the `eduPersonEntitlement` attribute in LDAP). The Dashboard and the Storage Service are treated as two seperate applications, each with their own `entityID`.

Because there are two applications, there needs to be two FastCGI handlers too. This requires a change to the [Supervisor configuration](etc/supervisor/conf.d/shibboleth.conf), to add the additional handler.
