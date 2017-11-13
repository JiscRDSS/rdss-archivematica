.DEFAULT_GOAL := build

BASE_DIR ?= ${CURDIR}

DEFAULT_COMPOSE_FILE = $(shell realpath ../docker-compose.qa.yml)

COMPOSE_FILE ?= "${DEFAULT_COMPOSE_FILE}"

all: destroy bootstrap
	docker-compose ps

build:
	# Specify compose file explicitly, we don't want to build any other container sets
	COMPOSE_FILE=$(DEFAULT_COMPOSE_FILE) docker-compose build

bootstrap: build bootstrap-storage-service bootstrap-dashboard restart-mcp-services

bootstrap-storage-service:
	# Wait for services to start properly to avoid race/timing problems
	@sleep 30
	docker-compose exec mysql mysql -hlocalhost -uroot -p12345 -e "\
		DROP DATABASE IF EXISTS SS; \
		CREATE DATABASE SS; \
		GRANT ALL ON SS.* TO 'archivematica'@'%' IDENTIFIED BY 'demo';"
	docker-compose run \
		--rm \
		--entrypoint /src/storage_service/manage.py \
			archivematica-storage-service \
				migrate --noinput
	docker-compose run \
		--rm \
		--entrypoint /src/storage_service/manage.py \
			archivematica-storage-service \
				create_user \
					--username="test" \
					--password="test" \
					--email="test@test.com" \
					--api-key="test" \
					--superuser

bootstrap-dashboard:
	# Wait for services to start properly to avoid race/timing problems
	@sleep 30
	docker-compose exec mysql mysql -hlocalhost -uroot -p12345 -e "\
		DROP DATABASE IF EXISTS MCP; \
		CREATE DATABASE MCP; \
		GRANT ALL ON MCP.* TO 'archivematica'@'%' IDENTIFIED BY 'demo';"
	docker-compose run \
		--rm \
		--entrypoint /src/dashboard/src/manage.py \
			archivematica-dashboard \
				migrate --noinput
	docker-compose run \
		--rm \
		--entrypoint /src/dashboard/src/manage.py \
			archivematica-dashboard \
				install \
					--username="test" \
					--password="test" \
					--email="test@test.com" \
					--org-name="test" \
					--org-id="test" \
					--api-key="test" \
					--ss-url="http://archivematica-storage-service:8000" \
					--ss-user="test" \
					--ss-api-key="test"

config:
	docker-compose config

# This does nothing but is required by the parent makefile
create-secrets:

destroy:
	COMPOSE_FILE=$(DEFAULT_COMPOSE_FILE) docker-compose down --volumes

list:
	docker-compose ps

restart-mcp-services:
	docker-compose restart archivematica-mcp-server archivematica-mcp-client

up: build
	$(foreach DIR, $(COMPOSE_DIRS), docker-compose up -d ;)
	@echo -n "Waiting 30 seconds for services to finish starting..."
	@sleep 30
	@echo " done."

watch-am:
	docker-compose logs -f archivematica-mcp-server archivematica-mcp-client archivematica-dashboard

watch-ss:
	docker-compose logs -f archivematica-storage-service

.PHONY: default destroy bootstrap build bootstrap-dashboard bootstrap-storage-service config create-secrets list restart-mcp-services
