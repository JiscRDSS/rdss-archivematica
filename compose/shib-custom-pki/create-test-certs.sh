#!/bin/bash

export ROOT_DOMAIN_NAME="${ROOT_DOMAIN_NAME:-acme.net}"
export ROOT_DOMAIN_ORG="${ROOT_DOMAIN_ORG:-ACME Network}"
export CA_DOMAIN_NAME="${CA_DOMAIN_NAME:-sample.org}"
export CA_DOMAIN_ORG="${CA_DOMAIN_ORG:-Sample International}"
export DOMAIN_NAME="${DOMAIN_NAME:-example.ac.uk}"
export DOMAIN_ORG="${DOMAIN_ORG:-Example University}"

CA_DIR="two-tier-ca"
DOMAIN_DIR="domains/${DOMAIN_NAME}"
CA_DOMAIN_DIR="domains/${CA_DOMAIN_NAME}"
ROOT_DOMAIN_DIR="domains/${ROOT_DOMAIN_NAME}"

BUILD_DIR="$(pwd)/build/${DOMAIN_NAME}"

create_private_key()
{
    local -r key_file="$1"
    if [ ! -f "${key_file}" ] ; then
        openssl genrsa -out "${key_file}" 4096
    fi
}

# Creates a certificate signing request for use with an IdP. Note that this adds
# DNS and URI alt_names to the CSR, as required for a Shibboleth IdP.
create_idp_signing_request()
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
OU=IT Services
O=${DOMAIN_ORG}
ST=London
L=London
C=GB
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
        -key "${key_in}" \
        -out "${csr_out}"
    # Remove temporary CSR config
    rm -f /tmp/csr.conf
}

create_signed_cert()
{
    local -r csr_file="$1"
    local -r cert_file="$2"
    if [ ! -f "${cert_file}" ] ; then
        local -r ca_key_file="${CA_DOMAIN_DIR}/ca/private/ca.key"
        local -r ca_cert_file="${CA_DOMAIN_DIR}/ca/certs/ca.crt"
        pushd "${CA_DIR}" && \
            openssl ca -batch \
                -config "${CA_DOMAIN_DIR}/ca.conf" \
                -in "${csr_file}" \
                -keyfile "${ca_key_file}" \
                -cert "${ca_cert_file}" \
                -out "${cert_file}"
        popd
    fi
}

create_sp_signing_request()
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
OU=IT Services
O=${DOMAIN_ORG}
ST=London
L=London
C=GB
emailAddress=admin@${DOMAIN_NAME}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${hostname}

EOF
    # Generate a CSR for the Shibboleth SP service
    openssl req -nodes -new \
        -config /tmp/csr.conf \
        -key "${key_in}" \
        -out "${csr_out}"
    # Remove temporary CSR config
    rm -f /tmp/csr.conf
}

create_web_signing_request()
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
OU=IT Services
O=${DOMAIN_ORG}
ST=London
L=London
C=GB
emailAddress=admin@${DOMAIN_NAME}

EOF
    # Generate a CSR for Shibboleth SP web interface (reusing existing key)
    openssl req -nodes -new \
        -config "/tmp/csr.conf" \
        -key "${key_in}" \
        -out "${csr_out}"
    # Remove temporary CSR config
    rm -f /tmp/csr.conf
}

generate_idp_certs()
{
    local -r idp_hostname="$1"
    mkdir -p "${BUILD_DIR}/.csr"
    # Create private key for Shibboleth IdP services
    local -r key_file="${BUILD_DIR}/idp.key"
    create_private_key "${key_file}"
    # Create the CSR for the IdP
    local -r csr_file="${BUILD_DIR}/.csr/${idp_hostname}.csr"
    create_idp_signing_request "${idp_hostname}" "${key_file}" "${csr_file}"
    # Generate a CA-signed cert for the IdP to present to browsers
    local -r cert_file="${BUILD_DIR}/idp.crt"
    create_signed_cert "${csr_file}" "${cert_file}"
}

generate_sp_certs()
{
    local -r app_name="$1"
    local -r app_host="$2"
    mkdir -p "${BUILD_DIR}/.csr"
    # Create private key
    local -r key_file="${BUILD_DIR}/${app_name}.key"
    create_private_key "${key_file}"
    # Create SP CSR
    local -r csr_file="${BUILD_DIR}/.csr/${app_host}.csr"
    create_sp_signing_request "${app_host}" "${key_file}" "${csr_file}"
    # Sign SP CSR
    local -r cert_file="${BUILD_DIR}/${app_name}.crt"
    create_signed_cert "${csr_file}" "${cert_file}"
    # Create CSR for nginx SSL
    local -r web_csr_file="${BUILD_DIR}/.csr/${app_host}-web.csr"
    create_web_signing_request "${app_host}" "${key_file}" "${web_csr_file}"
    # Sign nginx CSR
    local -r web_cert_file="${BUILD_DIR}/${app_name}-web.crt"
    create_signed_cert "${web_csr_file}" "${web_cert_file}"
    # Copy key for nginx
    local -r web_key_file="${BUILD_DIR}/${app_name}-web.key"
    cp -p "${key_file}" "${web_key_file}"
}

main()
{
    mkdir -p "${BUILD_DIR}"
    # Initialise the root and intermediate CAs
    pushd "${CA_DIR}" && ./init.sh ; popd
    # Copy the CA certs
    local -r src_root_cert_file="${CA_DIR}/${ROOT_DOMAIN_DIR}/root-ca/certs/root-ca.crt"
    local -r src_ca_cert_file="${CA_DIR}/${CA_DOMAIN_DIR}/ca/certs/ca.crt"
    local -r ca_cert_file="${BUILD_DIR}/ca.crt"
    local -r root_cert_file="${BUILD_DIR}/root-ca.crt"
    cp -p "${src_ca_cert_file}" "${ca_cert_file}"
    cp -p "${src_root_cert_file}" "${root_cert_file}"
    cat "${ca_cert_file}" "${root_cert_file}" > "${BUILD_DIR}/cabundle.pem"
    # Generate certs for the IdP
    generate_idp_certs "idp.${DOMAIN_NAME}"
    # Generate certs for the SPs
    generate_sp_certs "am-dash" "dashboard.archivematica.${DOMAIN_NAME}"
    generate_sp_certs "am-ss" "ss.archivematica.${DOMAIN_NAME}"
}

main $@
