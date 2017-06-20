#!/bin/bash

# Can be overridden by environment variables
DOMAIN_NAME=${DOMAIN_NAME:-"example.ac.uk"}
IDP_HOSTNAME=${IDP_HOSTNAME:-"idp.${DOMAIN_NAME}"}

#
# Globals
#

CA_DER_CERT="${DOMAIN_NAME}-ca.cer"
CA_PEM_CERT="${DOMAIN_NAME}-ca.crt"

IDP_CSR="${IDP_HOSTNAME}.csr"
IDP_DER_CERT="${IDP_HOSTNAME}.cer"
IDP_PEM_CERT="${IDP_HOSTNAME}.crt"
IDP_PEM_KEY="${IDP_HOSTNAME}.key"

IDP_BROWSER_P12="idp-browser.p12"
IDP_BACKCHANNEL_P12="idp-backchannel.p12"
IDP_CRYPTO_CERT="idp-encryption.crt"
IDP_CRYPTO_KEY="idp-encryption.key"
IDP_SIGNING_CERT="idp-signing.crt"
IDP_SIGNING_KEY="idp-signing.key"

CA_DIR="/src/ca"
BUILD_DIR="/build"

#
# Helper functions
#

create_key()
{
	local key_out="$1"
	[ -f "$key_out" ] || openssl genrsa -out "$1" 2048
}


# Creates a certificate signing request for use with an IdP. Note that this adds
# DNS and URI alt_names to the CSR, as required for a Shibboleth IdP.
create_idp_csr()
{
	local hostname="$1"
	local key_in="$2"
	local csr_out="$3"

	if [ -f "$csr_out" ] ; then
		return
	fi

	# Configure our CSR
	cat > /tmp/csr.conf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

[ dn ]
CN=${hostname}
C=GB
ST=London
L=London
emailAddress=admin@${DOMAIN_NAME}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${hostname}
URI.1 = https://${hostname}/idp/shibboleth

EOF
	# Generate a CSR for the IdP
	openssl req -nodes -new \
		-config "/tmp/csr.conf" \
		-passin pass:12345 -passout pass:12345 \
		-key "${key_in}" -out "${csr_out}"
	# Remove temporary CSR config
	rm -f /tmp/csr.conf
}

create_idp_keystore()
{
	local key_in="$1"
	local cert_in="$2"
	local ca_cert="$3"
	local ks_out="$4"

	[ -f "$ks_out" ] || openssl pkcs12 \
		-inkey "$1" \
		-in "$2" \
		-certfile "$3" \
		-export -out "$4" \
		-passout pass:12345
}

# Signs the given CSR with the domain's CA.
create_signed_cert()
{
	local hostname="$1"
	local csr="$2"
	local cert_out="$3"

	if [ -f "$cert_out" ] ; then
		return
	fi

	pushd "${CA_DIR}"
	local uniq_hostname="${hostname}.$(date +"%Y%m%d%H%M")"
	./sign.sh "${uniq_hostname}" "$csr"
	cp "domains/${DOMAIN_NAME}/certs/${uniq_hostname}.crt" "${cert_out}"
	popd
}

#
# Entry point
#

main()
{
	mkdir -p ${BUILD_DIR}
	# Create private key for Shibboleth IdP services
	create_key "${BUILD_DIR}/${IDP_PEM_KEY}"
	
	# Create the CSR for the IdP
	create_idp_csr "${IDP_HOSTNAME}" \
		"${BUILD_DIR}/${IDP_PEM_KEY}" \
		"${BUILD_DIR}/${IDP_CSR}"

	# Generate a CA-signed cert for the IdP to present to browsers
	create_signed_cert "${IDP_HOSTNAME}" \
		"${BUILD_DIR}/${IDP_CSR}" \
		"${BUILD_DIR}/${IDP_PEM_CERT}"
	
	# Copy CA cert
	cp -p "${CA_DIR}/domains/${DOMAIN_NAME}/certs/${CA_PEM_CERT}" \
		"${BUILD_DIR}/${CA_PEM_CERT}"

	# Bundle the key and certs into a P12 file
	create_idp_keystore "${BUILD_DIR}/${IDP_PEM_KEY}" \
		"${BUILD_DIR}/${IDP_PEM_CERT}" \
		"${BUILD_DIR}/${CA_PEM_CERT}" \
		"${BUILD_DIR}/${IDP_BROWSER_P12}"

	# Use the same key and cert for the backchannel, encryption and signing
	cp -p ${BUILD_DIR}/${IDP_BROWSER_P12} ${BUILD_DIR}/${IDP_BACKCHANNEL_P12}
	cp -p ${BUILD_DIR}/${IDP_PEM_CERT} ${BUILD_DIR}/${IDP_CRYPTO_CERT}
	cp -p ${BUILD_DIR}/${IDP_PEM_KEY} ${BUILD_DIR}/${IDP_CRYPTO_KEY}
	cp -p ${BUILD_DIR}/${IDP_PEM_CERT} ${BUILD_DIR}/${IDP_SIGNING_CERT}
	cp -p ${BUILD_DIR}/${IDP_PEM_KEY} ${BUILD_DIR}/${IDP_SIGNING_KEY}

	# Convert CA PEM cert to DER for Java keytool to import during bootstrap
	[ -f "${BUILD_DIR}/${CA_DER_CERT}" ] || openssl x509 -outform der \
		-in "${BUILD_DIR}/${CA_PEM_CERT}" \
		-out "${BUILD_DIR}/${CA_DER_CERT}"
}

main
