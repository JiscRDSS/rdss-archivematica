FROM unicon/shibboleth-idp:3.3.3

MAINTAINER Arkivum Limited

# Run commands:
# 1) Install openssl and unzip
# 2) Download and install xmlsectool
# 3) Make keytool executable
RUN yum install -y openssl unzip wget && \
  cd /opt && \
  wget "http://shibboleth.net/downloads/tools/xmlsectool/2.0.0/xmlsectool-2.0.0-bin.zip" && \
  unzip "xmlsectool-2.0.0-bin.zip" && \
  chmod +x "/opt/jre-home/bin/keytool"

# Copy the Shibboleth IdP files
COPY customized-shibboleth-idp/ /opt/shibboleth-idp/
