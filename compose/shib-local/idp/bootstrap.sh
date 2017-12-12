#!/bin/bash

JRE_HOME=/opt/jre-home

if [ -s /usr/share/pki/ca-trust-source/anchors/${DOMAIN_NAME}-ca.crt ] ; then
	exit
fi

# Copy CA cert into trusted location and update Linux trusted certs registry
cp -p /secrets/${DOMAIN_NAME}-ca.crt /usr/share/pki/ca-trust-source/anchors/ && update-ca-trust
# Also update JRE trusted certs so Tomcat trusts it too
chmod +x ${JRE_HOME}/bin/keytool
sleep 5
${JRE_HOME}/bin/keytool -import -noprompt -trustcacerts -alias ${DOMAIN_NAME} \
	-file /secrets/${DOMAIN_NAME}-ca.crt \
	-keystore  ${JRE_HOME}/lib/security/cacerts \
	-storepass changeit

# Wait for all metadata providers to be available
for m in $(grep metadataURL /opt/shibboleth-idp/conf/metadata-providers.xml | \
	sed -r 's/.+="([^"]+).*/\1/') ; do
	until curl -s -k "${m}" >/dev/null ; do
		echo "Waiting for ${m} to become available..."
		sleep 8
	done
	echo "Metadata available: ${m}"
done
