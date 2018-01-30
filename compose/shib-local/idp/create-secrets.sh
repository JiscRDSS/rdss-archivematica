#!/bin/bash

#
# Globals
#
BUILD_DIR="${BUILD_DIR:-/build}"
CA_DIR="${CA_DIR:-/src/ca}"
DOMAIN_NAME="${DOMAIN_NAME:-example.ac.uk}"

GENERATE_SSL_CERTS="${GENERATE_SSL_CERTS:-true}"

IDP_HOSTNAME="${IDP_HOSTNAME:-idp.${DOMAIN_NAME}}"

CA_DER_CERT="${DOMAIN_NAME}-ca.cer"
CA_PEM_CERT="${DOMAIN_NAME}-ca.crt"

IDP_CSR="${IDP_HOSTNAME}.csr"
IDP_DER_CERT="${IDP_HOSTNAME}.cer"
IDP_PEM_CERT="${IDP_HOSTNAME}.crt"
IDP_PEM_KEY="${IDP_HOSTNAME}.key"

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

generate_ssl_certs()
{
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
}

#
# Entry point
#

main()
{
	if [ "${GENERATE_SSL_CERTS}" == "true" ] ; then
		mkdir -p "${BUILD_DIR}" && generate_ssl_certs
	fi
}

main
