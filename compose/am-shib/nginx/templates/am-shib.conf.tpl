
# Expect long server names (e.g. 'dashboard.archivematica.test.institution.ac.uk')
server_names_hash_bucket_size 512;

#
# Archivematica Dashboard
#
server {
	listen ${AM_EXTERNAL_PORT:-443} ssl;
	server_name ${AM_DASHBOARD_HOST:-dashboard.archivematica.example.ac.uk};

	include /etc/nginx/conf.d/am-shib.inc;

	ssl_certificate     ${AM_DASHBOARD_SSL_WEB_CERT_FILE:-/secrets/nginx/am-dash-web-cert.pem};
	ssl_certificate_key ${AM_DASHBOARD_SSL_KEY_FILE:-/secrets/nginx/am-dash-key.pem};

	client_max_body_size 256M;

	set $upstream_endpoint http://archivematica-dashboard:8000;

	# By default, all resources are Shibboleth protected. Exceptions to this are
	# covered by the next location rule.
	location / {
		# Enforce authentication using Shibboleth
		include shib_clear_headers;
		more_clear_input_headers 'displayName' 'mail' 'persistent-id';
		shib_request /shibauthorizer;
		# Configure proxy
		proxy_set_header Host $http_host;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X_Forwarded-Proto https;
		proxy_redirect off;
		proxy_buffering off;
		proxy_read_timeout 172800s;
		proxy_pass $upstream_endpoint;
	}

	# Exclude /api and /media resources from Shibboleth protection.
	location ~* /(api|media)/ {
		# Configure proxy
		proxy_set_header Host $http_host;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X_Forwarded-Proto https;
		proxy_redirect off;
		proxy_buffering off;
		proxy_read_timeout 172800s;
		proxy_pass $upstream_endpoint;
	}

	# FastCGI authorizer for Auth Request module
	location = /shibauthorizer {
		internal;
		include fastcgi_params;
		include shib_fastcgi_params;
		fastcgi_param  HTTPS on;
		fastcgi_param  SERVER_PORT ${AM_EXTERNAL_PORT:-443};
		fastcgi_param  SERVER_PROTOCOL https;
		fastcgi_param  X_FORWARDED_PROTO https;
		fastcgi_param  X_FORWARDED_PORT ${AM_EXTERNAL_PORT:-443};
		fastcgi_pass unix:/tmp/am-ss-shibauthorizer.sock;
	}

	# FastCGI responder
	location /Shibboleth.sso {
		include fastcgi_params;
		fastcgi_param  HTTPS on;
		fastcgi_param  SERVER_PORT ${AM_EXTERNAL_PORT:-443};
		fastcgi_param  SERVER_PROTOCOL https;
		fastcgi_param  X_FORWARDED_PROTO https;
		fastcgi_param  X_FORWARDED_PORT ${AM_EXTERNAL_PORT:-443};
		fastcgi_pass unix:/tmp/am-ss-shibresponder.sock;
	}

	include /etc/nginx/incs/msgcreator.inc;

}

#
# Archivematica Storage Service
#
server {
	listen ${AM_EXTERNAL_PORT:-443} ssl;
	server_name ${AM_STORAGE_SERVICE_HOST:-ss.archivematica.example.ac.uk};

	include /etc/nginx/conf.d/am-shib.inc;

	ssl_certificate     ${AM_STORAGE_SERVICE_SSL_WEB_CERT_FILE:-/secrets/nginx/am-ss-web-cert.pem};
	ssl_certificate_key ${AM_STORAGE_SERVICE_SSL_KEY_FILE:-/secrets/nginx/am-ss-key.pem};

	client_max_body_size 256M;

	set $upstream_endpoint http://archivematica-storage-service:8000;

	# By default, all resources are Shibboleth protected. Exceptions to this are
	# covered by the next location rule.
	location / {
		# Enforce authentication using Shibboleth
		include shib_clear_headers;
		more_clear_input_headers 'displayName' 'mail' 'persistent-id';
		shib_request /shibauthorizer;
		# Configure proxy
		proxy_set_header Host $http_host;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X_Forwarded-Proto https;
		proxy_redirect off;
		proxy_buffering off;
		proxy_read_timeout 172800s;
		proxy_pass $upstream_endpoint;
	}

	# Exclude /api and /static resources from Shibboleth protection.
	location ~* /(api|static)/ {
		# Configure proxy
		proxy_set_header Host $http_host;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X_Forwarded-Proto https;
		proxy_redirect off;
		proxy_buffering off;
		proxy_read_timeout 172800s;
		proxy_pass $upstream_endpoint;
	}

	# FastCGI authorizer for Auth Request module
	location = /shibauthorizer {
		internal;
		include fastcgi_params;
		include shib_fastcgi_params;
		fastcgi_param  HTTPS on;
		fastcgi_param  SERVER_PORT ${AM_EXTERNAL_PORT:-443};
		fastcgi_param  SERVER_PROTOCOL https;
		fastcgi_param  X_FORWARDED_PROTO https;
		fastcgi_param  X_FORWARDED_PORT ${AM_EXTERNAL_PORT:-443};
		fastcgi_pass unix:/tmp/am-ss-shibauthorizer.sock;
	}

	# FastCGI responder
	location /Shibboleth.sso {
		include fastcgi_params;
		fastcgi_param  HTTPS on;
		fastcgi_param  SERVER_PORT ${AM_EXTERNAL_PORT:-443};
		fastcgi_param  SERVER_PROTOCOL https;
		fastcgi_param  X_FORWARDED_PROTO https;
		fastcgi_param  X_FORWARDED_PORT ${AM_EXTERNAL_PORT:-443};
		fastcgi_pass unix:/tmp/am-ss-shibresponder.sock;
	}
}

# Uncomment to enable debug logging
#error_log /var/log/nginx/debug.log debug;
