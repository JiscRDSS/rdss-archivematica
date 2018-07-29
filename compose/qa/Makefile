.DEFAULT_GOAL := build

BASE_DIR ?= ${CURDIR}

DEFAULT_COMPOSE_FILE = $(shell realpath ../docker-compose.qa.yml)

COMPOSE_FILE ?= "${DEFAULT_COMPOSE_FILE}"

MOCK_AWS ?= true
ifeq ("$(MOCK_AWS)", "true")
	DEFAULT_COMPOSE_FILE_2 := $(shell realpath ../docker-compose.mock-aws.qa.yml):$(DEFAULT_COMPOSE_FILE)
	override DEFAULT_COMPOSE_FILE=$(DEFAULT_COMPOSE_FILE_2)
endif

INSTRUMENTATION ?= false
ifeq ("$(INSTRUMENTATION)", "true")
	DEFAULT_COMPOSE_FILE_2 := $(shell realpath ../docker-compose.instrumentation.yml):$(DEFAULT_COMPOSE_FILE)
	override DEFAULT_COMPOSE_FILE=$(DEFAULT_COMPOSE_FILE_2)
endif

VERSION ?= $(shell git describe --tags --always --dirty)
export VERSION

define get_var_from_envfile
$(shell grep ^${1}= .env| tail -n1 | cut -d= -f2- | tr -d \'\" )
endef
# Read S3_AIP_STORE from .env file if they are not defined.
S3_AIP_STORE ?=  $(call get_var_from_envfile,S3_AIP_STORE)
S3_AIP_STORE_ACCESS_KEY_ID ?= $(call get_var_from_envfile,S3_AIP_STORE_ACCESS_KEY_ID)
S3_AIP_STORE_ENDPOINT_URL ?= $(call get_var_from_envfile,S3_AIP_STORE_ENDPOINT_URL)
S3_AIP_STORE_PATH ?= $(call get_var_from_envfile,S3_AIP_STORE_PATH)
S3_AIP_STORE_REGION ?= $(call get_var_from_envfile,S3_AIP_STORE_REGION)
S3_AIP_STORE_SECRET_ACCESS_KEY ?= $(call get_var_from_envfile,S3_AIP_STORE_SECRET_ACCESS_KEY)

all: destroy bootstrap
	docker-compose ps

build: build-docker build-nextcloud-apps

build-docker:
	# Specify compose file explicitly, we don't want to build any other container sets
	COMPOSE_FILE=$(DEFAULT_COMPOSE_FILE) docker-compose build

build-nextcloud-apps:
	# Make sure NextCloud apps are built
	@cd $(BASE_DIR)/../../src/rdss-arkivum-nextcloud/ && \
		make build-apps && cd $(BASE_DIR)

bootstrap: build bootstrap-storage-service bootstrap-dashboard bootstrap-dashboard-frontend restart-mcp-services

bootstrap-storage-service:
	# Wait for MySQL to be ready
	@until docker-compose exec mysql mysql -hlocalhost -uroot -p12345 \
		-e 'SELECT count(1) FROM mysql.user;' >/dev/null 2>&1 ; do \
			echo "Waiting for mysql to be ready..." ; \
			sleep 8 ; \
	done
	# Create Storage Service database if required and grant default access
	docker-compose exec mysql mysql -hlocalhost -uroot -p12345 -e "\
		CREATE DATABASE IF NOT EXISTS SS; \
		GRANT ALL ON SS.* TO 'archivematica'@'%' IDENTIFIED BY 'demo';"
	# Run Storage Service database migrations
	docker-compose run \
		--rm \
		--entrypoint /src/storage_service/manage.py \
			archivematica-storage-service \
				migrate --noinput
	# Add initial Storage Service user account
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
	# Wait for MySQL to be ready
	@until docker-compose exec mysql mysql -hlocalhost -uroot -p12345 \
		-e 'SELECT count(1) FROM mysql.user;' >/dev/null 2>&1 ; do \
			echo "Waiting for mysql to be ready..." ; \
			sleep 8 ; \
	done
	# Create Dashboard database if required and grant default access
	docker-compose exec mysql mysql -hlocalhost -uroot -p12345 -e "\
		CREATE DATABASE IF NOT EXISTS MCP; \
		GRANT ALL ON MCP.* TO 'archivematica'@'%' IDENTIFIED BY 'demo';"
	# Run Dashboard database migrations
	docker-compose run \
		--rm \
		--entrypoint /src/dashboard/src/manage.py \
			archivematica-dashboard \
				migrate --noinput
	# Add initial Dashboard user account
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
					--ss-api-key="test" \
					--site-url="http://archivematica-dashboard:8000/"
	# Create RDSS storage locations
	docker-compose exec archivematica-storage-service \
		python /rdss/create-storage-locations.py \
			--base-url http://localhost:8000 \
			--api-user test \
			--api-key test

ifeq ("$(S3_AIP_STORE)", "true")
	# Create RDSS S3 space and AIP store
	docker-compose exec archivematica-storage-service \
		python /rdss/create-s3-space-location.py \
			--base-url http://localhost:8000 \
			--api-user test \
			--api-key test \
			--s3-access-key-id "$(S3_AIP_STORE_ACCESS_KEY_ID)" \
			--s3-secret-access-key "$(S3_AIP_STORE_SECRET_ACCESS_KEY)" \
			--s3-path "$(S3_AIP_STORE_PATH)" \
			--s3-region "$(S3_AIP_STORE_REGION)" \
			--s3-endpoint-url "$(S3_AIP_STORE_ENDPOINT_URL)"
endif

bootstrap-dashboard-frontend:
	docker-compose run --rm --no-deps \
		--user root \
		--entrypoint npm \
		--workdir /src/dashboard/frontend/transfer-browser \
			archivematica-dashboard \
				install --unsafe-perm
	docker-compose run --rm --no-deps \
		--user root \
		--entrypoint npm \
		--workdir /src/dashboard/frontend/appraisal-tab \
			archivematica-dashboard \
				install --unsafe-perm

config:
	docker-compose config

# This does nothing but is required by the parent makefile
create-secrets:

destroy:
	COMPOSE_FILE=$(DEFAULT_COMPOSE_FILE) docker-compose down --volumes

list:
	docker-compose ps

ifeq ($(RESET_PROCESSING_CONFIG), true)
restart-mcp-services: reset-processing-configs
else
restart-mcp-services:
endif
	docker-compose restart archivematica-mcp-server archivematica-mcp-client

reset-processing-configs:
	# Remove the builtin processing configs so the originals can be restored when mcp server restarts
	docker-compose run --rm --no-deps \
		--user root \
		--entrypoint rm \
		--workdir /var/archivematica/sharedDirectory/sharedMicroServiceTasksConfigs/processingMCPConfigs/ \
			archivematica-mcp-server \
				-f automatedProcessingMCP.xml defaultProcessingMCP.xml;

up: build
	$(foreach DIR, $(COMPOSE_DIRS), docker-compose up -d ;)
	@echo -n "Waiting 30 seconds for services to finish starting..."
	@sleep 30
	@echo " done."

watch-am:
	docker-compose logs -f archivematica-mcp-server archivematica-mcp-client archivematica-dashboard

watch-ss:
	docker-compose logs -f archivematica-storage-service

.PHONY: default destroy bootstrap build build-docker build-nextcloud-apps bootstrap-dashboard bootstrap-dashboard-frontend bootstrap-storage-service config create-secrets list restart-mcp-services
