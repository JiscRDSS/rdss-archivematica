# Pin against last release that used debian 8, to avoid incompatibility with debian 9
FROM osixia/openldap@sha256:443571790e7db8dd7072d31003089fbec1acf490340173c34a39cd6f4aa345e5

MAINTAINER Arkivum Limited

# Copy the bootstrap script to a location where the Osixia container set up will
# find it
COPY bootstrap.sh /container/service/ldap-bootstrap/process.sh

# Install the 'runit' tool because Osixia requires it for multi-service image
RUN apt-get -y update && /container/tool/add-service-available :runit
