Common Shibboleth Services
===========================

This folder contains the definitions for services that are common to all Shibboleth-based deployments. In particular, it includes:

1. [Shibboleth Identity Provider](idp) (IdP) service
1. [Nginx-Shibboleth](nginx) service, which includes the [Shibboleth FastCGI Service Provider](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPFastCGIConfig) deployed [alongside nginx](https://github.com/nginx-shib/nginx-http-shibboleth)
1. [LDAP](ldap) service, providing directory services to the IdP
1. [Certificate Authority](ca) configuration, which is used to create CA-issued certificates for a configured domain

Shibboleth Identity Provider
-----------------------------

This container uses the `arkivum/shibboleth-idp` image, which extends the [unicorn/shibboleth-idp](https://hub.docker.com/r/unicon/shibboleth-idp/) image, and uses CentOS 7 as its base image.

The software run by this image is the off-the-shelf [Shibboleth IdP](https://shibboleth.net/products/identity-provider.html), which runs as a Java webapp in Jetty. The IdP does not ship with a default configuration - instead a build script is provided to create a `customized-shibboleth-idp` directory that is then expected to be modified manually to customize the IdP to meet requirements. This is fine unless the installation is being automated - we want to be able to bring up containers unattended, if need be.

The [idp](idp) does quite a lot in its build script prior to the `docker-compose build` step. In particular, it runs the [init-idp.sh](idp/bin/init-idp.sh) script, which creates the `customized-shibboleth-idp` directory for modification. The configuration is modified to enable Single Log Out (SLO) functionality and to replace the keys used to encrypt the SSL connections, and for data encryption and signing (see [Certificate Authority](#certificate-authority), below).

More details about the IdP service can be found in its [README](idp/README.md).

Nginx with Shibboleth Support
------------------------------

The [nginx](nginx) container provides a build of [nginx](https://www.nginx.com) that has the [nginx-shibboleth module](https://github.com/nginx-shib/nginx-http-shibboleth) enabled. This uses the [Shibboleth FastCGI Service Provider](https://wiki.shibboleth.net/confluence/display/SHIB2/NativeSPFastCGIConfig) that is hosted alongside `nginx` in the same container, in order to provide Shibboleth authentication functionality.

This container overrides the [dev/nginx](../dev/nginx) container and extends the [virtualstaticvoid/shibboleth-nginx](https://hub.docker.com/r/virtualstaticvoid/shibboleth-nginx/) image, which has Debian Wheezy as its base OS.

Because `systemd` doesn't work well within containers, [supervisord](http://supervisord.org/) is used to run the Shibboleth and Nginx services.

More information can be found in the [README](nginx/README.md).

LDAP Service
-------------

The [LDAP](ldap) service is used to provide a user directory for the Shibboleth IdP. This container uses the [osixia/openldap](https://hub.docker.com/r/osixia/openldap/) image, which has Debian Jessie as its base OS.

The container image isn't customized but configuration is added. In particular, the [eduOrg and eduPerson schema](https://spaces.internet2.edu/display/macedir/LDIFs) are added, as well as some demo user accounts.

More details can be found in the [README](ldap/README.md).

Certificate Authority
----------------------

Shibboleth works best when messages are signed and parties are trusted. The Certificate Authority (CA) allows this public-key-based infrastructure to be implemented, providing a way to issue signed certificates so that different parties (IdP and SPs) can trust each other.

The CA isn't actually a container or service in the normal way; it is initialised at build time, and used as part of the build to configure services and their containers.

More details about the CA can be found in its [README](ca/README.md).
