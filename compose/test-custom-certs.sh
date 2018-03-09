#!/bin/bash

# Define the root, intermediate and service domains
export ROOT_DOMAIN_NAME="storytellersweb.net"
export ROOT_DOMAIN_ORG="Story Tellers Network"
export CA_DOMAIN_NAME="nurserytimes.net"
export CA_DOMAIN_ORG="Nursery Times"
export DOMAIN_NAME="dishandspoon.co.uk"
export DOMAIN_ORG="Dish and Spoon Ltd"
export DOMAIN_ORGANISATION="${DOMAIN_ORG}"

# Create the custom certs
pushd shib-custom-pki && ./create-test-certs.sh ; popd

# Bring up the compose environment without generating default certs
make all SHIBBOLETH_CONFIG=archivematica GENERATE_CERTS=false

# Reconfigure to use custom pki files
docker-compose \
    -f docker-compose.qa.yml \
    -f docker-compose.am-shib.yml \
    -f docker-compose.shib-local.yml \
    -f docker-compose.am-shib-custom.yml \
    -f docker-compose.shib-local-custom.yml \
    up -d --build --no-deps --force-recreate \
    nginx-ssl shib-sp-proxy idp

