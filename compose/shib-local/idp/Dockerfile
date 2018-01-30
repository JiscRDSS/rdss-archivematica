FROM unicon/shibboleth-idp

MAINTAINER Arkivum Limited

# Run commands:
# 1) Install openssl
# 2) Make keytool executable
RUN yum install -y openssl && \
  chmod +x "/opt/jre-home/bin/keytool"

# Copy the Shibboleth IdP files
COPY customized-shibboleth-idp/ /opt/shibboleth-idp/
