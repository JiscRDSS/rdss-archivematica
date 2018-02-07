FROM nginx:stable-alpine

# Download envplate and delete default nginx site config
RUN apk --no-cache add curl && \
    curl -sLo /usr/local/bin/ep \
        https://github.com/kreuzwerker/envplate/releases/download/v0.0.8/ep-linux && \
    chmod +x /usr/local/bin/ep && \
    rm -f /etc/nginx/conf.d/default.conf

# Process config using envplate
CMD ["/usr/local/bin/ep", "-v", "/etc/nginx/conf.d/am-ssl.conf", "--", "/bin/sh", "-c", "nginx -g 'daemon off;'"]

# Copy our config template
COPY am-ssl.conf.tpl /etc/nginx/conf.d/am-ssl.conf