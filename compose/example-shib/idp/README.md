Shibboleth Example: IdP Service
================================

This service provides a "concrete" instance of the [shib/idp](../shib/idp) service.

It provides the [service-providers.json](etc/service-providers.json) file, which is used by the [build script](build.sh) to use the [idp-metadata-providers.py](../../shib/idp-metadata-providers.py) script to generate the required `metadata-providers.xml` used by the IdP to describe the SPs it knows about.

In this Shibboleth example, we have two SPs: the FastCGI one within the `nginx` container, and the one within the `sp` container, running the [SP1](sp) service.
