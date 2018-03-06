
# Use localhost as the resolver
resolver 127.0.0.11;

# Expect long server names (e.g. 'dashboard.archivematica.test.institution.ac.uk')
server_names_hash_bucket_size 512;

#
# Archivematica Dashboard
#
server {
	listen ${AM_EXTERNAL_PORT:-443} ssl;
	server_name ${AM_DASHBOARD_HOST:-dashboard.archivematica.example.ac.uk};

	# SSL configuration
	ssl_protocols       SSLv3 TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers         HIGH:!aNULL:!MD5;
	ssl_session_cache   shared:SSL:10m;
	ssl_session_timeout 10m;
	ssl_certificate     ${AM_DASHBOARD_SSL_WEB_CERT_FILE:-/secrets/ssl-proxy/am-dash-cert.pem};
	ssl_certificate_key ${AM_DASHBOARD_SSL_KEY_FILE:-/secrets/ssl-proxy/am-dash-key.pem};

	client_max_body_size 256M;

	set $upstream_endpoint http://${SHIB_SP_HOST}:80;

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

#
# Archivematica Storage Service
#
server {
	listen ${AM_EXTERNAL_PORT:-443} ssl;
	server_name ${AM_STORAGE_SERVICE_HOST:-ss.archivematica.example.ac.uk};

	# SSL configuration
	ssl_protocols       SSLv3 TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers         HIGH:!aNULL:!MD5;
	ssl_session_cache   shared:SSL:10m;
	ssl_session_timeout 10m;
	ssl_certificate     ${AM_STORAGE_SERVICE_SSL_WEB_CERT_FILE:-/secrets/ssl-proxy/am-ss-cert.pem};
	ssl_certificate_key ${AM_STORAGE_SERVICE_SSL_KEY_FILE:-/secrets/ssl-proxy/am-ss-key.pem};

	client_max_body_size 256M;

	set $upstream_endpoint http://${SHIB_SP_HOST}:80;

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
