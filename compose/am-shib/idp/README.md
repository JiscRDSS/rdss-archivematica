Shibboleth-enabled Archivematica: IdP Service
==============================================

This service provides a "concrete" instance of the [shib/idp](../shib/idp) service.

It provides the [service-providers.json](etc/service-providers.json) file, which is used by the [build script](build.sh) to use the [idp-metadata-providers.py](../../shib/idp-metadata-providers.py) script to generate the required `metadata-providers.xml` used by the IdP to describe the SPs it knows about.

In this Archivematica Shibboleth deployment, we have two SPs: one for the Archivematica Dashboard and one for the Archivematica Storage Service. Although part of the same product they run on different ports they have different endpoints, hence it is simplest to treat them as different SPs as far as the IdP is concerned.

In reality, the Dashboard and Storage Service are both serviced by the same SP; see the relevant [nginx](../nginx) service for details.
