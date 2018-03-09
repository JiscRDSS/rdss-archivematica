#!/bin/bash

DOMAIN_NAME="${DOMAIN_NAME:-example.ac.uk}"
IDP_HOSTNAME="${IDP_HOSTNAME:-idp.${DOMAIN_NAME}}"

# Input key and certs
IDP_SSL_KEY_FILE="${IDP_SSL_KEY_FILE:-/secrets/${IDP_HOSTNAME}.key}"
IDP_SSL_CERT_FILE="${IDP_SSL_CERT_FILE:-/secrets/${IDP_HOSTNAME}.crt}"
IDP_SSL_CA_CERT_FILE="${IDP_SSL_CA_CERT_FILE:-/secrets/${DOMAIN_NAME}-ca.crt}"
IDP_SSL_KEYSTORE_PASSWORD="${IDP_SSL_KEYSTORE_PASSWORD:-12345}"

# Output paths
DEST_DIR=/etc/pki/shibboleth-idp
CA_DER_CERT="${DEST_DIR}/${DOMAIN_NAME}-ca.cer"
IDP_BACKCHANNEL_P12="${DEST_DIR}/idp-backchannel.p12"
IDP_BROWSER_P12="${DEST_DIR}/idp-browser.p12"
IDP_CRYPTO_CERT="${DEST_DIR}/idp-encryption.crt"
IDP_CRYPTO_KEY="${DEST_DIR}/idp-encryption.key"
IDP_SIGNING_CERT="${DEST_DIR}/idp-signing.crt"
IDP_SIGNING_KEY="${DEST_DIR}/idp-signing.key"

prepare_idp_certs()
{
	# Remove any existing generated certs/keys etc
	rm -f \
		"${IDP_BROWSER_P12}" "${IDP_BACKCHANNEL_P12}" \
		"${IDP_CRYPTO_CERT}" "${IDP_CRYPTO_KEY}" \
		"${IDP_SIGNING_CERT}" "${IDP_SIGNING_KEY}"
	# Bundle the key and certs into a P12 file for use by Jetty
	openssl pkcs12 \
		-inkey "${IDP_SSL_KEY_FILE}" -in "${IDP_SSL_CERT_FILE}" \
		-certfile "${IDP_SSL_CA_CERT_FILE}" -export -out "${IDP_BROWSER_P12}" \
		-passout pass:"${IDP_SSL_KEYSTORE_PASSWORD}"
	# Use the same key and cert for the backchannel, encryption and signing
	cp -p "${IDP_BROWSER_P12}" "${IDP_BACKCHANNEL_P12}"
	cp -p "${IDP_SSL_CERT_FILE}" "${IDP_CRYPTO_CERT}"
	cp -p "${IDP_SSL_KEY_FILE}" "${IDP_CRYPTO_KEY}"
	cp -p "${IDP_SSL_CERT_FILE}" "${IDP_SIGNING_CERT}"
	cp -p "${IDP_SSL_KEY_FILE}" "${IDP_SIGNING_KEY}"
	# Update conf to use given IDP keystore password
	mkdir -p /opt/shibboleth-idp/ext-conf && \
	cat > /opt/shibboleth-idp/ext-conf/idp-secrets.properties << EOF
jetty.backchannel.sslContext.keyStorePassword=${IDP_SSL_KEYSTORE_PASSWORD}
jetty.sslContext.keyStorePassword=${IDP_SSL_KEYSTORE_PASSWORD}
EOF
}

sign_idp_metadata()
{
	if [ ! -e "/opt/shibboleth-idp/metadata/idp-metadata.xml" ] ; then
		pushd "/opt/xmlsectool-2.0.0" && \
			JAVA_HOME=/opt/jre-home/ ./xmlsectool.sh --sign \
				--inFile /opt/shibboleth-idp/metadata/idp-metadata.unsigned.xml \
				--outFile /opt/shibboleth-idp/metadata/idp-metadata.xml \
				--certificate "${IDP_SIGNING_CERT}" \
				--key "${IDP_SIGNING_KEY}"
		popd
	fi
}

main()
{
	mkdir -p "${DEST_DIR}"

	# Use the input key and certs to create various keys/certs/stores for IdP
	prepare_idp_certs

	if [ ! -s /usr/share/pki/ca-trust-source/anchors/${DOMAIN_NAME}-ca.crt ] ; then
		# Convert CA PEM cert to DER for Java keytool to import
		if [ ! -f "${CA_DER_CERT}" ] ; then
			openssl x509 \
				-outform der \
				-in "${IDP_SSL_CA_CERT_FILE}" \
				-out "${CA_DER_CERT}"
		fi
		# Copy CA cert into trusted location and update Linux trusted certs registry
		cp -p "${IDP_SSL_CA_CERT_FILE}" \
			/usr/share/pki/ca-trust-source/anchors/ && \
			update-ca-trust
		# Also update JRE trusted certs so Tomcat trusts it too
		/opt/jre-home/bin/keytool -import -noprompt -trustcacerts \
			-alias "${DOMAIN_NAME}" \
			-file "${CA_DER_CERT}" \
			-keystore  "/opt/jre-home/lib/security/cacerts" \
			-storepass changeit
	fi

	# Make Jetty the owner of all destination files
	chown -R jetty:jetty "${DEST_DIR}"/*

	# Sign IdP metadata
	sign_idp_metadata

	# Wait for all metadata providers to be available
	for m in $(grep metadataURL /opt/shibboleth-idp/conf/metadata-providers.xml | \
		sed -r 's/.+="([^"]+).*/\1/') ; do
		until curl -s -S -I "${m}" | grep '200 OK' > /dev/null ; do
			echo "Waiting for ${m} to become available..."
			sleep 8
		done
		echo "Metadata available: ${m}"
	done
}

main
