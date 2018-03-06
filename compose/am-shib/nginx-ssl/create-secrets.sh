#!/bin/bash

#
# Globals
#

BUILD_DIR="${BUILD_DIR:-/build}"
CA_DIR="${CA_DIR:-/src/ca}"
DOMAIN_NAME="${DOMAIN_NAME:-example.ac.uk}"

GENERATE_SSL_CERTS="${GENERATE_SSL_CERTS:-true}"

CA_PEM_CERT="${DOMAIN_NAME}-ca.crt"

AM_DASHBOARD_HOST="${AM_DASHBOARD_HOST:-dashboard.archivematica.${DOMAIN_NAME}}"
AM_STORAGE_SERVICE_HOST="${AM_STORAGE_SERVICE_HOST:-ss.archivematica.${DOMAIN_NAME}}"

AM_DASHBOARD_KEY="am-dash-key.pem"
AM_DASHBOARD_CERT="am-dash-cert.pem"
AM_DASHBOARD_CSR="${AM_DASHBOARD_HOST}.csr"

AM_STORAGE_SERVICE_KEY="am-ss-key.pem"
AM_STORAGE_SERVICE_CERT="am-ss-cert.pem"
AM_STORAGE_SERVICE_CSR="${AM_STORAGE_SERVICE_HOST}.csr"


#
# Helper functions
#

create_key()
{
	local key_out="$1"
	[ -f "$key_out" ] || openssl genrsa -out "$1" 2048
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

create_web_csr()
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
distinguished_name = dn
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

[ dn ]
CN=${hostname}
C=GB
ST=London
L=London
emailAddress=admin@${DOMAIN_NAME}

EOF
	# Generate a CSR for Shibboleth SP web interface (reusing existing key)
	openssl req -nodes -new \
		-config "/tmp/csr.conf" \
		-passin pass:12345 -passout pass:12345 \
		-key "${key_in}" -out "${csr_out}"
	# Remove temporary CSR config
	rm -f /tmp/csr.conf
}

generate_ssl_certs()
{
	#
	# AM Dashboard
	#
	# Create private key
	create_key "${BUILD_DIR}/${AM_DASHBOARD_KEY}"
	# Create CSR for nginx SSL
	create_web_csr "${AM_DASHBOARD_HOST}" \
		"${BUILD_DIR}/${AM_DASHBOARD_KEY}" \
		"${BUILD_DIR}/${AM_DASHBOARD_CSR}"
	# Sign nginx CSR
	create_signed_cert "${AM_DASHBOARD_HOST}" \
		"${BUILD_DIR}/${AM_DASHBOARD_CSR}" \
		"${BUILD_DIR}/${AM_DASHBOARD_CERT}"

	#
	# AM Storage Service
	#
	# Create private key
	create_key "${BUILD_DIR}/${AM_STORAGE_SERVICE_KEY}"
	# Create CSR for nginx SSL
	create_web_csr "${AM_STORAGE_SERVICE_HOST}" \
		"${BUILD_DIR}/${AM_STORAGE_SERVICE_KEY}" \
		"${BUILD_DIR}/${AM_STORAGE_SERVICE_CSR}"
	# Sign nginx CSR
	create_signed_cert "${AM_STORAGE_SERVICE_HOST}" \
		"${BUILD_DIR}/${AM_STORAGE_SERVICE_CSR}" \
		"${BUILD_DIR}/${AM_STORAGE_SERVICE_CERT}"
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
