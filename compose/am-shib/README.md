Shibboleth-enabled Archivematica Services
===========================================

The containers in this `docker-compose` service set provide an Archivematica deployment that uses Shibboleth authentication to secure access. They comprise the default Archivematica services (including Dashboard and Storage Service), as well as a modified `nginx` service that includes the Shibboleth Service Provider (SP) to enable Shibboleth authentication.

The Shibboleth nginx service runs the [nginx](https://www.nginx.com) web server with the [nginx-shibboleth module](https://github.com/nginx-shib/nginx-http-shibboleth) enabled. In addition, it runs the [Shibboleth FastCGI SP](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPFastCGIConfig) application, which `nginx` communicates with via UNIX sockets, as well as [supervisord](http://supervisord.org/) to run the Shibboleth components as daemons (in the absence of `systemd` in a Docker container).

The docker image for this service is based on [virtualstaticvoid/shibboleth-nginx](https://hub.docker.com/r/virtualstaticvoid/shibboleth-nginx/) image, which in turn has Debian Wheezy as its base OS.

The nginx service hosts two virtual servers, one for the Archivematica Dashboard on port 443, and one for the Archivematica Storage Service on port 8443. Each server is configured with the required Shibboleth locations, as well as the `/` location, which is secured by Shibboleth. Some resources, such as `/api` and static media are not secured, because they don't need to be.

By default this service is configured to be available at `https://archivematica.example.ac.uk/`.

Building
---------

This service can be built using `docker build`. However, since it depends on the main Archivematica services, it is recommended that the parent [compose](compose) makefile is used instead.

### Arguments

The [Dockerfile](nginx/Dockerfile) used to build the image takes a number of arguments.

| Argument | Description |
|---|---|
| NGINX_CONF_TEMPLATE_FILE | Path of the nginx config template file, which will be used to create `/etc/nginx/conf.d/am-shib.conf`. This is specifically concerned with Shibboleth-enabled services, not anything else that may be hosted by `nginx`. |
| SHIBBOLETH_CONF_TEMPLATE_FILE | Path of the Shibboleth config template file, which will be used to create `/etc/shibboleth/shibboleth2.xml`. |

All of the above arguments are required; there are no defaults.

Configuration
--------------

The files in [etc](nginx/rootfs/etc) that configure this service are grouped by the process to which they relate - one of `nginx`, the `shibd` SP, or `supervisor`.

* [nginx](nginx/rootfs/etc/nginx)
	* [am-shib.inc](nginx/rootfs/etc/nginx/conf.d/am-shib.inc) includes some common SSL/Shibboleth settings for nginx
	* [archivematica.conf](nginx/rootfs/etc/nginx/conf.d/archivematica.conf) overrides the default, non-Shibboleth nginx configuration for Archivematica, enabling alternatives to be set.
	* [shib_clear_headers](nginx/rootfs/etc/nginx/shib_clear_headers) clears HTTP headers related to Shibboleth, to avoid spoofing etc
	* [shib_fastcgi_params](nginx/rootfs/etc/nginx/shib_fastcgi_params) defines a number of FastCGI parameters specific to Shibboleth
* [shibboleth](nginx/rootfs/etc/shibboleth)
	* [attrChecker.html](nginx/rootfs/etc/shibboleth/attrChecker.html) | HTML page to present when checking attributes has failed.
	* [attrChecker.pl](nginx/rootfs/etc/shibboleth/attrChecker.pl) may be used to update `attrChecker.html` based on the SP's metadata.
	* [attribute-map.xml](nginx/rootfs/etc/shibboleth/attribute-map.xml) defines how attributes from the IdP are interpreted. See [official documentation](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPAttributeExtractor) for more details.
	* [attribute-policy.xml](nginx/rootfs/etc/shibboleth/attribute-policy.xml) defines what validation is done on the attributes from an IdP. See the [official documentation](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPAttributeFilter) for more details.
	* [console.logger](nginx/rootfs/etc/shibboleth/console.logger) configures logging for the Shibboleth SP console tools (see [Diagnostics](#diagnostics), below).
	* [security-policy.xml](nginx/rootfs/etc/shibboleth/security-policy.xml) overrides the default security policy in terms of trusting signatures etc. See [Security Policies](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPSecurityPolicies) documentation for more on this.
	* [shibd.logger](nginx/rootfs/etc/shibboleth/shibd.logger) configures logging for the Shibd daemon process, which responds to the FastCGI calls. This configuration causes all logging to go to `stdout` and `stderr`, so that `docker logs` can pick them up.
* [supervisor](nginx/rootfs/etc/supervisor)
	* [shibboleth.conf](nginx/rootfs/etc/supervisor/conf.d/shibboleth.conf), which adds an additional SP handler to the Supervisor, to accomodate both the Dashboard and Storage services.

Template Files
---------------

This service makes use of several templated configuration files. These are referenced by arguments to the Dockerfile, as follows:

| Variable | Description | Default File |
|---|---|---|
| NGINX_CONFIG_TEMPLATE_FILE | Provides the template for the `/etc/nginx/conf.d/am-shib.conf` file. This is expected to include configuration for interfacing with the SP FastCGI module, as well as defining which locations are protected by Shibboleth in their configuration. | [am-shib.conf.tpl](nginx/templates/am-shib.conf.tpl) |
| SHIBBOLETH_CONFIG_TEMPLATE_FILE | Provides the template for the `/etc/shibboleth/shibboleth2.xml` file. This configures how the SP functions; see the [SP configuration documentation](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPConfiguration) for full details of what can be in this configuration file. | [shibboleth2.xml.tpl](nginx/templates/shibboleth2.xml.tpl]) |

These templates are interpreted using [envplate](https://github.com/kreuzwerker/envplate) at instantiation time, since `envplate` is used as the `ENTRYPOINT` for the parent `virtualstaticvoid/shibboleth-nginx` image. This is why they are included at build time via the Dockerfile, rather than at run-time via a volume mount. If a volume were used then the original would be overwritten, since `envplate` uses in-place substitutions.

Environment Variables
----------------------

The following environment variables are used by these service containers:

| Variable | Description |
|---|---|
| AM_DASHBOARD_EXTERNAL_PORT | The external port that the Archivematica Dashboard should be exposed on. Default is 443. |
| AM_DASHBOARD_SSL_CA_BUNDLE_FILE | The CA certificates file to secure the Archivematica Dashboard with for Shibboleth communications. This is expected to be a bundle, with the whole certificate chain included. | `/secrets/nginx/sp-ca-bundle.pem` |
| AM_DASHBOARD_SSL_CERT_FILE | The certificate file to secure the Archivematica Dashboard with for Shibboleth communications. | `/secrets/nginx/am-dash-cert.pem` |
| AM_DASHBOARD_SSL_KEY_FILE | The private key file to secure the Archivematica Dashboard service with. | `/secrets/nginx/am-dash-key.pem` |
| AM_DASHBOARD_SSL_WEB_CERT_FILE | The certificate file to secure the Archivematica Dashboard web service with. | `/secrets/nginx/am-dash-web-cert.pem` |
| AM_STORAGE_SERVICE_EXTERNAL_PORT | The external port that the Archivematica Storage Service should be exposed on. Default is 8443 |
| AM_STORAGE_SERVICE_SSL_CA_BUNDLE_FILE | The CA certificates file to secure the Archivematica Storage Service with for Shibboleth communications. This is expected be a bundle, with the whole certificate chain included. | `/secrets/nginx/sp-ca-bundle.pem` |
| AM_STORAGE_SERVICE_SSL_CERT_FILE | The certificate file to secure the Archivematica Storage Service with for Shibboleth communications. | `/secrets/nginx/am-ss-cert.pem` |
| AM_STORAGE_SERVICE_SSL_KEY_FILE | The private key file to secure the Archivematica Storage Service service with. | `/secrets/nginx/am-ss-key.pem` |
| AM_STORAGE_SERVICE_SSL_WEB_CERT_FILE | The certificate file to secure the Archivematica Storage Service web service with. | `/secrets/nginx/am-ss-web-cert.pem` |
| NGINX_EXTERNAL_IP | The external IP address that `nginx` should bind to. Default is `0.0.0.0`, meaning the service is available on all interfaces. |
| SHIBBOLETH_IDP_ENTITY_ID | The `entityID` of the IdP that the SP should use for authentication. By default it will use the local Shibboleth IdP service. |
| SHIBBOLETH_IDP_METADATA_URL | The URL of the IdP metadata that the SP should use for authentication. By default it will contact the local Shibboleth IdP service to obtain its metadata. |
| `SHIBBOLETH_METADATA_SIGNING_CERT` | Certificate file to use to verify the signature of metadata responses from the IdP. | `ukfederation-mdq.pem` |
| `SHIBBOLETH_METADATA_URL_SUBST` | The "substitution string" to use when determining the metadata URL for the IdP's entity id. | `http://mdq.ukfederation.org.uk/entities/$entityID` |

Entitlements
-------------

The [shibboleth2.xml template](nginx/templates/shibboleth2.xml.tpl) includes access control elements that restrict access to the Dashboard and Storage Service based on a user's entitlements. These are expected to be derived from the `eduPersonEntitlement` attribute provided by the IdP:

| Entitlement | Archivematica Access |
|---|---|
| `preservation-admin` | admin |
| `preservation-user` | default |

Users without either of these entitlements will currently be denied access to Archivematica services.

From a Shibboleth point of view, the Dashboard and the Storage Service are treated as two seperate applications, each with their own SP and `entityID`.


SSL Certificates
-----------------

The certificates and private keys that should be used to secure the Shibboleth services can be specified using the `AM_DASHBOARD_SSL_*` and `AM_STORAGE_SERVICE_SSL_*` environment variables described above. If none of these values are set, default keys and self-signed certificates will be generated and used by the Compose bootstrap process.

The environment variables must be applied to the `nginx` container, because that is where the SSL layer is applied. For example, using docker-compose:

```
services:
  nginx:
    environment:
      AM_DASHBOARD_SSL_KEY_FILE:              '/secrets/dash-private-key.pem'
      AM_DASHBOARD_SSL_CERT_FILE:             '/secrets/dash-sp-certificate.pem'
      AM_DASHBOARD_SSL_WEB_CERT_FILE:         '/secrets/dash-web-certificate.pem'
      AM_DASHBOARD_SSL_CA_BUNDLE_FILE:        '/secrets/cabundle.pem'
      AM_STORAGE_SERVICE_SSL_KEY_FILE:        '/secrets/ss-private-key.pem'
      AM_STORAGE_SERVICE_SSL_CERT_FILE:       '/secrets/ss-sp-certificate.pem'
      AM_STORAGE_SERVICE_SSL_WEB_CERT_FILE:   '/secrets/ss-web-certificate.pem'
      AM_STORAGE_SERVICE_SSL_CA_BUNDLE_FILE:  '/secrets/cabundle.pem'
    volumes:
      - '/keys/dash/private-key.pem:/secrets/dash-private-key.pem:ro'
      - '/keys/dash/sp-certificate.pem:/secrets/dash-sp-certificate.pem:ro'
      - '/keys/dash/web-certificate.pem:/secrets/dash-web-certificate.pem:ro'
      - '/keys/ss/private-key.pem:/secrets/ss-private-key.pem:ro'
      - '/keys/ss/sp-certificate.pem:/secrets/ss-sp-certificate.pem:ro'
      - '/keys/ss/web-certificate.pem:/secrets/ss-web-certificate.pem:ro'
      - '/keys/cabundle.pem:/secrets/cabundle.pem:ro'
```

There are two different types of service being secured by SSL: the Shibboleth SP for each application, and the Nginx virtual host for each application. Each application is expected to have a different hostname, which means different CNs, which requires different certificates to secure it (unless using a wildcard certificate, but we cannot assume this). 

In addition, the application SP certificates must include the "subject alt name" of the host, as a "DNS" entry in the certificate metadata. This means that they must be seperate to those used by `nginx`. If using OpenSSL to create the SP certificates then the following must be added to the OpenSSL config:

```
[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${hostname}
```

This is exactly as they are used in the [create-secrets.sh](nginx/create-secrets.sh) script, in which the OpenSSL config is generated (hence the use of `${hostname}` instead of a static value).

Currently, any intermediate certificates should be bundled in the CA certificate files.

All key and certificate files must be in PEM format.



Shibboleth Metadata
--------------------

The Shibboleth SPs are configured to use a dynamic metadata provider. This means that the IdP's entity id will be used to determine the URL to request metadata from, and the returned metadata will have its signature checked against a given certificate.

By default it is assumed that the IdP will be a well-known identity provide registered with the UKAMF, so the metadata URL will be resolved using the substitution `http://mdq.ukfederation.org.uk/entities/$entityID`. To override this, set the `SHIBBOLETH_METADATA_URL_SUBST` environment variable.

The certificate used to verify the signature of the metadata may also be specified. By default the `ukfederation-mdq.pem` certificate will be used, which is pre-installed in the image, but setting `SHIBBOLETH_METADATA_SIGNING_CERT` will override this and use the file path specified. The file given must be mounted from the host into the container using a volume mount.


Diagnostics
------------

To aid diagnostics, a number of tools are included in the Shibboleth SP installation in this container. These are standard tools, publicly available, that are either installed by default or that have been included specifically.

The notes here are intended to give an overview of each tool, and also to raise awareness that they even exist, since their documentation is buried deep in the official Shibboleth documentation. Hopefully this knowledge will save a lot of time and frustration when working with Shibboleth and its configuration!

As well as these, see the documentation for [aacli](https://wiki.shibboleth.net/confluence/display/SHIB2/AACLI), which can be used to debug issues on the IdP side.

### AttrChecker

the [attrChecker](https://github.com/CSCfi/shibboleth-attrchecker) is included as an additional page that intercepts requests if they don't have a required list of attributes being sent from the IdP. This is useful to ensure that the SP is configured correctly, and also that the IdP is sending the necessary parameters.

The intercept is dependent on the SP including the following `sessionHook` and `Handler` in its configuration:

	<ApplicationDefaults sessionHook="/Shibboleth.sso/AttrChecker" ... >
		<Sessions>
			<Handler type="AttributeChecker" Location="/AttrChecker" attributes="cn entitlement eppn givenName mail sn" template="attrChecker.html" flushSession="true" showAttributeValues="true"/>
			...
		</Sessions>
		...
	</ApplicationDefaults>

The `attributes` attribute of the `Handler` element should be updated to match the list of attributes the SP requires from IdPs for the application to function.

### MDQuery

The `mdquery` tool allows the configuration for metadata in the SP to be checked. Its full documentation is [here](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPmdquery).

As an example, here's how you might check the IdP metadata for the SAML2 protocol:

	mdquery -e https://idp.example.ac.uk/idp/shibboleth -saml2 -idp

When using this tool, extra log output can be obtained by modifying the `console.logger` config file to set the log level to `DEBUG`.

### ResolverTest

The `resolvertest` tool can be used to test what attributes the SP receives from the IdP and what survive the various filters etc. Its full documentation is [here](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPresolvertest).

As an example, here's how you might check what happens when the SP tries to resolve the attributes for the user `aa` for the `am-dash` application:

	resolvertest -a am-dash -i https://idp.example.ac.uk/idp/shibboleth -saml2 -n aa@example.ac.uk

As with `mdquery`, the `console.logger` configuration file can be used to increase the logging level to offer more information for diagnostics.

### Shibd

This isn't really a tool as such. The `shibd` executable is intended to be run as a daemon, but it can also be used to test the validity of the `shibboleth2.xml` configuration file. Its full documentation is [here](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPshibd).

For example:

	shibd -t

This starts the `shibd` service in the foreground, loads its configuration, and then shuts the service down again and exits. If you need to increase the log level for this, use the `shibd.logger` configuration file.
