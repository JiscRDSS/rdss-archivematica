#!/bin/bash

ROOT_DOMAIN_NAME="${ROOT_DOMAIN_NAME:-example.net}"
ROOT_DOMAIN_ORG="${ROOT_DOMAIN_ORG:-Example University}"

CA_DOMAIN_NAME="${CA_DOMAIN_NAME:-my.example.net}"
CA_DOMAIN_ORG="${CA_DOMAIN_ORG:-My Example University}"

ROOT_DOMAIN_DIR="domains/${ROOT_DOMAIN_NAME}"
CA_DOMAIN_DIR="domains/${CA_DOMAIN_NAME}"

ROOT_CA_CONFIG="${ROOT_DOMAIN_DIR}/root-ca.conf"
CA_CONFIG="${CA_DOMAIN_DIR}/ca.conf"

ROOT_CA_DIR="${ROOT_DOMAIN_DIR}/root-ca"
CA_DIR="${CA_DOMAIN_DIR}/ca"

create_ca_config()
{
    local -r conf_template="$1"
    local -r conf_file="$2"
    local -r ca_name="$3"
    local -r ca_dir="$4"
    local -r domain_name="$5"
    local -r domain_org="$6"
    cp -p "${conf_template}" "${conf_file}"
    sed -i -e "s/[\$]{CA_NAME}/${ca_name}/" \
        -e "s#[\$]{CA_DIR}#${ca_dir}#" \
        -e "s#[\$]{DOMAIN_NAME}#${domain_name}#" \
        -e "s#[\$]{DOMAIN_ORG}#${domain_org}#" \
        "${conf_file}"
}

create_ca_crl()
{
    local -r conf_file="$1"
    local -r key_file="$2"
    local -r cert_file="$3"
    local -r crl_file="$4"
    if [ -f "${cert_file}" -a -f "${key_file}" ] ; then
        openssl ca -gencrl \
               -keyfile "${key_file}" -cert "${cert_file}" -out "${crl_file}" \
               -config "${conf_file}"
    fi
}

create_ca_database()
{
    local -r db_dir="$1"
    # Create the required root CA database files
    if [ ! -f "${db_dir}/index.txt" ] ; then
        touch ${db_dir}/index.txt
    fi
    if [ ! -f "${db_dir}/serial" ] ; then
        echo "1000" > ${db_dir}/serial
    fi
    if [ ! -f "${db_dir}/crlnumber" ] ; then
        echo "01" > ${db_dir}/crlnumber
    fi
}

create_certificate()
{
    local -r conf_file="$1"
    local -r key_file="$2"
    local -r cert_file="$3"
    local -r subject="$4"
    if [ ! -f "${cert_file}" ] ; then
        openssl req -new -x509 -days 3650 \
            -key "${key_file}" -out "${cert_file}" -config "${conf_file}" \
            -subj "${subject}"
    fi
}

create_private_key()
{
    local -r key_file="$1"
    if [ ! -f "${key_file}" ] ; then
        openssl genrsa -out "${key_file}" 4096
    fi
}

create_signing_request()
{
    local -r conf_file="$1"
    local -r key_file="$2"
    local -r csr_file="$3"
    local -r subject="$4"
    if [ ! -f "${csr_file}" ] ; then
        openssl req -new -sha256 -key "${key_file}" -subj "${subject}" \
            -out "${csr_file}"
    fi
}

init_ca()
{
    mkdir -p "${CA_DIR}"/{certs,db,newcerts,private}

    # Create the intermediate CA config from template
    create_ca_config "ca.conf.tpl" \
        "${CA_CONFIG}" \
        "${CA_DOMAIN_NAME}-ca" \
        "${CA_DIR}" \
        "${CA_DOMAIN_NAME}" \
        "${CA_DOMAIN_ORG}"

    # Create the database files
    create_ca_database "${CA_DIR}/db"

    # Create a private key
    local -r priv_key_file="${CA_DIR}/private/ca.key"
    create_private_key "${priv_key_file}"

    # Create a signing request
    local -r csr_file="${CA_DIR}/private/${DOMAIN_NAME}.csr"
    create_signing_request "${CA_CONFIG}" "${priv_key_file}" "${csr_file}" \
        "/CN=${CA_DOMAIN_NAME}/OU=${CA_DOMAIN_ORG} CA/O=${CA_DOMAIN_ORG}"

    # Sign the CSR with the given root CA
    local -r ca_dir="${ROOT_CA_DIR}"
    local -r ca_cert_file="${CA_DIR}/certs/ca.crt"
    sign_request "root-ca" "${ca_dir}" "${csr_file}" "${ca_cert_file}"
}

init_root_ca()
{
    mkdir -p "${ROOT_CA_DIR}"/{certs,db,newcerts,private}

    # Create the root CA config from template
    create_ca_config "root-ca.conf.tpl" \
        "${ROOT_CA_CONFIG}" \
        "${ROOT_DOMAIN_NAME}-ca" \
        "${ROOT_CA_DIR}" \
        "${ROOT_DOMAIN_NAME}" \
        "${ROOT_DOMAIN_ORG}"

    # Create the database files
    create_ca_database "${ROOT_CA_DIR}/db"

    # Create a private key
    local -r priv_key_file="${ROOT_CA_DIR}/private/root-ca.key"
    create_private_key "${priv_key_file}"

    # Create a public certificate
    local -r cert_file="${ROOT_CA_DIR}/certs/root-ca.crt"
    create_certificate "${ROOT_CA_CONFIG}" \
        "${priv_key_file}" \
        "${cert_file}" \
        "/CN=${ROOT_DOMAIN_NAME}/OU=${ROOT_DOMAIN_ORG} Root CA/O=${ROOT_DOMAIN_ORG}"

    # Initialize the CRL
    local -r crl_file="${ROOT_CA_DIR}/certs/${ROOT_DOMAIN_NAME}.crl"
    create_ca_crl "${ROOT_CA_CONFIG}" "${priv_key_file}" "${cert_file}" "${crl_file}"
}

sign_request()
{
    local -r ca_name="$1"
    local -r ca_dir="$2"
    local -r csr_file="$3"
    local -r cert_file="$4"
    if [ ! -f "${cert_file}" ] ; then
        local -r ca_key_file="${ca_dir}/private/${ca_name}.key"
        local -r ca_cert_file="${ca_dir}/certs/${ca_name}.crt"
        openssl ca -batch \
            -config "${ROOT_CA_CONFIG}" \
            -in "${csr_file}" \
            -keyfile "${ca_key_file}" \
            -cert "${ca_cert_file}" \
            -out "${cert_file}"
    fi
}

main()
{
    init_root_ca && init_ca
}

main $@
