location /msgcreator {
	set $upstream_endpoint http://rdss-archivematica-msgcreator:8000/;

	proxy_redirect off;
	proxy_pass $upstream_endpoint;
}
