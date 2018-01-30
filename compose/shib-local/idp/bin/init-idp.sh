#!/bin/bash

DOMAIN_NAME="${DOMAIN_NAME:-example.ac.uk}"

IDP_HOSTNAME="${IDP_HOSTNAME:-idp.${DOMAIN_NAME}}"
IDP_LDAP_HOSTNAME="${IDP_LDAP_HOSTNAME:-ldap.${DOMAIN_NAME}}"

IDP_DOMAIN="${DOMAIN_NAME}"
IDP_DOMAIN_BASEDN="$(echo -n DC=${IDP_DOMAIN} | sed 's#[.]#,DC=#g')"
IDP_EXTERNAL_PORT="${IDP_EXTERNAL_PORT:-4443}"
IDP_KEYSTORE_PASSWORD="${IDP_KEYSTORE_PASSWORD:-12345}"

export JAVA_HOME=/opt/jre-home
export PATH=$PATH:$JAVA_HOME/bin

# Generate idp.properties based on template and env vars
sed "s|[\$]{IDP_DOMAIN_BASEDN}|${IDP_DOMAIN_BASEDN}|g" /setup/conf/idp.properties.tpl | \
	sed "s|[\$]{IDP_DOMAIN}|${IDP_DOMAIN}|g" | \
	sed "s|[\$]{IDP_EXTERNAL_PORT}|${IDP_EXTERNAL_PORT}|g" | \
	sed "s|[\$]{IDP_HOSTNAME}|${IDP_HOSTNAME}|g" | \
	sed "s|[\$]{IDP_KEYSTORE_PASSWORD}|${IDP_KEYSTORE_PASSWORD}|g" | \
	sed "s|[\$]{IDP_LDAP_HOSTNAME}|${IDP_LDAP_HOSTNAME}|g" > /tmp/idp.properties

# Change into the Shibboleth IdP bin directory ready for the build
cd /opt/shibboleth-idp/bin

# Remove existing config so build starts with an empty config
rm -r ../conf/

# Hard-code the build parameters for our example IdP
./build.sh \
	-Didp.noprompt \
	-Didp.target.dir=/opt/shibboleth-idp \
	-Didp.host.name=${IDP_HOSTNAME} \
	-Didp.keystore.password=${IDP_KEYSTORE_PASSWORD} \
	-Didp.sealer.password=${IDP_KEYSTORE_PASSWORD} \
	-Didp.merge.properties=/tmp/idp.properties \
	metadata-gen

mkdir -p /ext-mount/customized-shibboleth-idp/conf/

# Copy the essential and routinely customized config to our Docker mount.
cd ..
cp -r credentials/ /ext-mount/customized-shibboleth-idp/
cp -r metadata/ /ext-mount/customized-shibboleth-idp/
cp conf/{attribute-resolver.xml,attribute-filter.xml,cas-protocol.xml,idp.properties,ldap.properties,metadata-providers.xml,relying-party.xml,saml-nameid.xml} /ext-mount/customized-shibboleth-idp/conf/

# Copy the basic UI components, which are routinely customized
cp -r views/ /ext-mount/customized-shibboleth-idp/
mkdir -p /ext-mount/customized-shibboleth-idp/webapp/
cp -r webapp/css/ /ext-mount/customized-shibboleth-idp/webapp/
cp -r webapp/images/ /ext-mount/customized-shibboleth-idp/webapp/
cp -r webapp/js/ /ext-mount/customized-shibboleth-idp/webapp/
rm -r /ext-mount/customized-shibboleth-idp/views/user-prefs.js

# Remove backchannel keys and certs because they're self-signed - we'll replace them later
rm /ext-mount/customized-shibboleth-idp/credentials/idp-*

# Enable SLO via HTTP in IdP metadata config
# (commented out section starts at line 110 so splice the file to 'edit' the XML)
head -n 109 /ext-mount/customized-shibboleth-idp/metadata/idp-metadata.xml \
	> idp-metadata.xml.head
tail -n +111 /ext-mount/customized-shibboleth-idp/metadata/idp-metadata.xml \
	| head -n 3 > idp-metadata.xml.mid
tail -n +116 /ext-mount/customized-shibboleth-idp/metadata/idp-metadata.xml \
	> idp-metadata.xml.tail
cat idp-metadata.xml.head idp-metadata.xml.mid idp-metadata.xml.tail \
	> idp-metadata.xml

# Replace IdP host with actual 'external' host/port
sed -i "s|Location=\"https://${IDP_HOSTNAME}/idp/|Location=\"https://${IDP_HOSTNAME}:${IDP_EXTERNAL_PORT}/idp/|g" idp-metadata.xml

cp idp-metadata.xml /ext-mount/customized-shibboleth-idp/metadata/

# Change owner on all exported files to be IDP_OWNER_UID:IDP_OWNER_GID
chown -R ${IDP_OWNER_UID:-0}:${IDP_OWNER_GID:-0} /ext-mount
chmod -R u+rwX /ext-mount
