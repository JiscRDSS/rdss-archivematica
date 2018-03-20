#!/usr/bin/env python

"""
This script is used to automatically generate the IdP metadata providers
configuration from a list of Service Providers based on their metadata URL.
The output is content for a metadata-providers.xml file suitable for use as
part of the configuration of an Shibboleth IdP.

Example input content:

	{
	  "am-dashboard" : {
	    "metadata": "https://archivematica.${DOMAIN_NAME}/Shibboleth.sso/metadata"
	  },
	  "am-storage-service" : {
	    "metadata": "https://archivematica.${DOMAIN_NAME}:8443/Shibboleth.sso/metadata"
	  }
	}

Arguments:
	This script expects a single argument, the path to the JSON file to read
	input from.
"""

import json
import os
import sys

# Check we got our service providers YAML file as the first param
if len(sys.argv) == 1:
	print ("FATAL! You must provide the path to the service-providers.yml as the first argument!")
	sys.exit(1)

sp_conf_file = sys.argv[1]

# Print the MetadataProvider XML header
print ("""<?xml version="1.0"?>
<MetadataProvider id="ShibbolethMetadata" xsi:type="ChainingMetadataProvider"
    xmlns="urn:mace:shibboleth:2.0:metadata"
    xmlns:resource="urn:mace:shibboleth:2.0:resource"
    xmlns:security="urn:mace:shibboleth:2.0:security"
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="urn:mace:shibboleth:2.0:metadata http://shibboleth.net/schema/idp/shibboleth-metadata.xsd
                        urn:mace:shibboleth:2.0:resource http://shibboleth.net/schema/idp/shibboleth-resource.xsd 
                        urn:mace:shibboleth:2.0:security http://shibboleth.net/schema/idp/shibboleth-security.xsd
                        urn:oasis:names:tc:SAML:2.0:metadata http://docs.oasis-open.org/security/saml/v2.0/saml-schema-metadata-2.0.xsd">""")

# For each of our services, output a MetadataProvider element
with open(sp_conf_file, 'r') as f:
   sp_conf = json.load(f)
   for sp in sp_conf:
      metadata_url = sp_conf[sp]['metadata'].replace(
         '${AM_DASHBOARD_HOST}', os.getenv('AM_DASHBOARD_HOST', 'dashboard.archivematica.example.ac.uk')).replace(
         '${AM_STORAGE_SERVICE_HOST}', os.getenv('AM_STORAGE_SERVICE_HOST', 'ss.archivematica.example.ac.uk')).replace(
         '${AM_EXTERNAL_PORT}', os.getenv('AM_EXTERNAL_PORT', '443')).replace(
         '${NEXTCLOUD_HOST}', os.getenv('NEXTCLOUD_HOST', 'nextcloud.example.ac.uk'))
      print ("""
    <MetadataProvider xsi:type="FileBackedHTTPMetadataProvider"
        id="{name}Metadata"
        metadataURL="{metadata}"
        backingFile="%{{idp.home}}/metadata/{name}_metadata.xml">
    </MetadataProvider>""".format(name = sp, metadata=metadata_url))

# Print the MetadataProvider XML footer
print ("\n</MetadataProvider>")
