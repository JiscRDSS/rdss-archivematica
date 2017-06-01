LDAP Service
=============

The [LDAP](ldap) service is used to provide a user directory for the Shibboleth IdP. This container uses the [osixia/openldap](https://hub.docker.com/r/osixia/openldap/) image, which has Debian Jessie as its base OS.

The container image isn't customized but configuration is added. In particular, the [eduOrg and eduPerson schema](https://spaces.internet2.edu/display/macedir/LDIFs) are added, as well as some demo user accounts.

Building
---------

The [build script](build.sh) processes the template for the demo user accounts and sets their domain to the configured domain name and organisation:

	./build.sh

The default domain for the LDAP service is "example.ac.uk", with the top-level organizational unit (OU) as "Example University". This can be changed by overriding the `DOMAIN_NAME` and `DOMAIN_ORGANISATION` environment variables.

	DOMAIN_NAME=my.edu DOMAIN_ORGANISATION="My Academy" ./build.sh

This is all that is required to "customize" the LDAP service to provide directory services to a Shibboleth IdP.

Usage
------

To make use of the eduPerson schema it must be added to the LDAP directory at runtime, after the service has been started. This can be done using the `docker-compose exec` command, as in the [am-shib](../../am-shib/Makefile) bootstrap:

	# Install LDAP edu schema
	docker-compose exec ldap /usr/local/ldap/edu/install.sh
	# Install LDAP demo users docker-compose exec ldap \
		ldapadd \
			-D "cn=admin,${LDAP_DOMAIN}" -w admin \
			-f "/usr/local/ldap/demo-users.ldif"

This assumes that the files in [etc/ldap/edu](etc/ldap/edu) have been mounted as a volume under `/usr/ldap/edu` in the service container. The [install](etc/ldap/edu/install.sh) script performs the required steps to install the edu schema into the LDAP directory, prior to the `ldapadd` command above being used to import the demo user account records.

Demo Users
-----------

There are 3 demo user accounts, "Alice Arnold", "Bert Bellwether" and "Charlie Cooper".

* Alice has the entitlements of `matlab-user` and `preservation-user`, allowing her to access Archivematica as a normal user.
* Bert has the entitlement `preservation-admin`, allowing him to access Archivematica as an admin user.
* Charlie has the entitlement `matlab-user`, allowing him no access to Archivematica.

See the [LDIF template](etc/ldap/demo-users.ldif.tpl) for details of their credentials.

For these accounts the `eduPersonPrincipalName` (`eppn` for short) gets used as the Archivematica username. This is configurable in the IdP and SP layers, should it need to be changed.

Deployment
-----------

This service is intended primarily for development/internal use. In production, it is expected that a real LDAP or Active Directory service would be used, and the IdP would be configured to use that instead.
