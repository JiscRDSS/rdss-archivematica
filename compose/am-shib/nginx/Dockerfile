FROM virtualstaticvoid/shibboleth-nginx

MAINTAINER Arkivum Limited

# Environment variables

# Override responder path - for some reason the parent image uses '/saml'
# instead of the official default '/Shibboleth.sso'
ENV SHIBBOLETH_RESPONDER_PATH "/Shibboleth.sso"

#
# Nginx configuration
# 1) Ensure the nginx user exists and belongs to the shibd group
# 2) Redirect Nginx debug logs to stderr
#
# Shibboleth customizations
# 1) Redirect Shibboleth logs to stdout and stderr
#
RUN useradd -s /bin/nologin nginx && usermod -G _shibd nginx && \
    rm -f /var/log/nginx/debug.log /var/log/shibboleth/shibd*.log && \
    ln -s /dev/stderr /var/log/nginx/debug.log && \
    ln -s /dev/stdout /var/log/shibboleth/shibd.log && \
    ln -s /dev/stderr /var/log/shibboleth/shibd_warn.log

# Process configs using envplate and bootstrap before passing to supervisor
CMD ["/usr/local/bin/ep", \
      "-v", "/etc/nginx/conf.d/am-shib.conf", "/etc/shibboleth/shibboleth2.xml", \
      "--", \
      "/bin/sh", "-c", \
      "bootstrap.sh && /usr/bin/supervisord --nodaemon --configuration /etc/supervisor/supervisord.conf" \
    ]

# Listen on 443
EXPOSE 443

# Copy rootfs files
COPY rootfs /

# Templates

# Specifies the path of the nginx config template file. Required.
ARG NGINX_CONF_TEMPLATE_FILE

# Specifies the path of the Shibboleth config template file. Required.
ARG SHIBBOLETH_CONF_TEMPLATE_FILE

COPY $NGINX_CONF_TEMPLATE_FILE /etc/nginx/conf.d/am-shib.conf
COPY $SHIBBOLETH_CONF_TEMPLATE_FILE /etc/shibboleth/shibboleth2.xml
