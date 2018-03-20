#
# NextCloud
#
server {
	listen ${NEXTCLOUD_EXTERNAL_SSL_PORT:-443} ssl;
	server_name ${NEXTCLOUD_HOST:-nextcloud.example.ac.uk};

	# SSL configuration
	ssl_protocols       SSLv3 TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers         HIGH:!aNULL:!MD5;
	ssl_session_cache   shared:SSL:10m;
	ssl_session_timeout 10m;
	ssl_certificate     ${NEXTCLOUD_SSL_CERT_FILE:-/secrets/ssl-proxy/nextcloud-cert.pem};
	ssl_certificate_key ${NEXTCLOUD_SSL_KEY_FILE:-/secrets/ssl-proxy/nextcloud-key.pem};

	client_max_body_size 256M;

	set $upstream_endpoint http://${NEXTCLOUD_PROXIED_HOST}:8888;

	location / {
		# Configure proxy
		proxy_set_header Host $http_host;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto https;
		proxy_redirect off;
		proxy_buffering off;
		proxy_read_timeout 172800s;
		proxy_pass $upstream_endpoint;
	}
}
