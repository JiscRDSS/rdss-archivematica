Shibboleth: Common Nginx Service
=================================

The Shibboleth Nginx service runs the [nginx](https://www.nginx.com) web server with the [nginx-shibboleth module](https://github.com/nginx-shib/nginx-http-shibboleth) enabled. In addition, it runs the [Shibboleth FastCGI SP](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPFastCGIConfig) application, which `nginx` communicates with via UNIX sockets, as well as [supervisord](http://supervisord.org/) to run the Shibboleth components as daemons (in the absence of `systemd` in a Docker container).

Docker Image
-------------

The docker image for this service is based on [virtualstaticvoid/shibboleth-nginx](https://hub.docker.com/r/virtualstaticvoid/shibboleth-nginx/) image, which in turn has Debian Wheezy as its base OS.

### Arguments

The [Dockerfile](Dockerfile) used to build the image takes a number of arguments.

| Argument | Description |
|---|---|
| CA_CERT_FILE | Path of the CA certificate file, used to provide context to the SP certificate file. |
| DOMAIN_NAME | The domain that the service is part of, e.g. `example.com`. |
| NGINX_CONF_TEMPLATE_FILE | Path of the nginx config template file, which will be used to create `/etc/nginx/conf.d/default.conf`. This is specifically concerned with Shibboleth-enabled services, not anything else that may be hosted by `nginx`. |
| SHIBBOLETH_CONF_TEMPLATE_FILE | Path of the Shibboleth config template file, which will be used to create `/etc/shibboleth/shibboleth2.xml`. |
| SP_CERT_FILE | Path of the SP certificate file, used for communicating with Identity Provider(s). |
| SP_KEY_FILE | Path of the SP private key file. |
| SP_WEB_CERT_FILE | Path of the SP web certificate file, used to secure the HTTPS web interface for the SP, e.g. for redirects and/or error pages etc. |

All of the above arguments are required; there are no defaults.

Building
---------

The [build script](build.sh) is provided to make building images with the required arguments easier. For example:

	./build.sh -c /tmp/example-ca.crt -d example.com \
		-k /tmp/sp-key.pem -s /tmp/sp-cert.pem -w /tmp/sp-web-cert.pem \
		-n /tmp/nginx.conf.tpl -x /tmp/shibboleth2.xml.tpl

As well as checking that each of these arguments is given and is valid, the build script also "bundles" the various files into a `ctx` folder, which is then passed to the `docker build` command. This is because Docker cannot use files outside of the base directory, so copying the input files and providing `ctx` as the base ensures all files can be found.

This image is not intended to be used as-is; the configuration is missing the necessary `shibboleth2.xml`, which configures the Shibboleth SP component, and `default.conf`, which configures the Nginx Shibboleth usage. See the [am-shib build ](../../am-shib/nginx/build.sh) and the [example-shib build](../../example-shib/nginx/build.sh) for concrete examples of its usage.

Template Files
---------------

This service makes use of two templated configuration files, neither of which aren't included in this base configuration. These are referenced by arguments to the Dockerfile, as follows:

| Template File Variable | Description |
|---|---|
| NGINX_CONFIG_TEMPLATE_FILE | Provides the template for the `/etc/nginx/conf.d/default.conf` file. This is expected to include configuration for interfacing with the SP FastCGI module, as well as defining which locations are protected by Shibboleth in their configuration. |
| SHIBBOLETH_CONFIG_TEMPLATE_FILE | Provides the template for the `/etc/shibboleth/shibboleth2.xml` file. This configures how the SP functions; see the [SP configuration documentation](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPConfiguration) for full details of what can be in this configuration file.

Both of these templates are interpreted using [envplate](https://github.com/kreuzwerker/envplate) at instantiation time, since `envplate` is used as the `ENTRYPOINT` for the parent `virtualstaticvoid/shibboleth-nginx` image.

Configuration Files
--------------------

The files in [etc](etc) configure this abstract service, but may be overridden in a concrete service definition. The base files are as follows:

* `nginx/shib_clear_headers` clears HTTP headers related to Shibboleth, to avoid spoofing etc
* `nginx/shib_fastcgi_params` defines a number of FastCGI parameters specific to Shibboleth
* `shibboleth/attrChecker.html` provides a diagnostics page for checking attributes sent by an IdP for an authenticated user (see [Diagnostics](#diagnostics), below).
* `shibboleth/attrChecker.pl` may be used to update `attrChecker.html` based on the SP's metadata.
* `shibboleth/console.logger` configures logging for the Shibboleth SP console tools (see [Diagnostics](#diagnostics), below).
* `shibboleth/security-policy.xml` overrides the default security policy in terms of trusting signatures etc. See [Security Policies](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPSecurityPolicies) documentation for more on this.
* `shibboleth/shibd.logger` configures logging for the Shibd daemon process, which responds to the FastCGI calls. This configuration causes all logging to go to `stdout` and `stderr`, so that `docker logs` can pick them up.

Diagnostics
------------

To aid diagnostics, a number of tools are included in the Shibboleth SP installation in this container. These are standard tools, publicly available, that are either installed by default or that have been included specifically.

The notes here are intended to give an overview of each tool, and also to raise awareness that they even exist, since their documentation is buried deep in the official Shibboleth documentation. Hopefully this knowledge will save a lot of time and frustration when working with Shibboleth and its configuration!

### AttrChecker

the [attrChecker]() is included as an additional page that intercepts requests if they don't have a required list of attributes being sent from the IdP. This is useful to ensure that the SP is configured correctly, and also that the IdP is sending the necessary parameters.

The intercept is dependent on the concrete service including the following `sessionHook` and `Handler` in its configuration:

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

The `resovlvertest` tool can be used to test what attributes the SP receives from the IdP and what survive the various filters etc. Its full documentation is [here](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPresolvertest).

As an example, here's how you might check what happens when the SP tries to resolve the attributes for the user `aa` for the `archivematica-dashboard` application:

	resolvertest -a archivematica-dashboard -i https://idp.example.ac.uk/idp/shibboleth -saml2 -n aa@example.ac.uk

As with `mdquery`, the `console.logger` configuration file can be used to increase the logging level to offer more information for diagnostics.

### Shibd

This isn't really a tool as such. The `shibd` executable is intended to be run as a daemon, but it can also be used to test the validity of the `shibboleth2.xml` configuration file. Its full documentation is [here](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPshibd).

For example:

	shibd -t

This starts the `shibd` service in the foreground, loads its configuration, and then shuts the service down again and exits. If you need to increase the log level for this, use the `shibd.logger` configuration file.
