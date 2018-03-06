.DEFAULT_GOAL := build

SUB_DIRS := $(sort $(wildcard */))

BASE_DIR ?= ${CURDIR}

VOL_BASE ?= $(BASE_DIR)/..

DEFAULT_COMPOSE_FILE = $(shell realpath ../docker-compose.am-shib.yml)

COMPOSE_FILE ?= "${DEFAULT_COMPOSE_FILE}"

DOMAIN_NAME ?= "example.ac.uk"

LDAP_DOMAIN = $(shell echo -n dc=$(DOMAIN_NAME) | sed 's/[.]/,dc=/g')

GENERATE_SSL_CERTS ?= "true"

all: destroy clean build create-secrets up bootstrap list

# This is needed by upstream makefile
bootstrap:

build:
	# Build the services. These depend on those in dev, so include that config too
	COMPOSE_FILE=${COMPOSE_FILE} docker-compose build

clean:
	rm -Rf "$(BASE_DIR)/build"

config:
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose config

create-secrets: create-sp-proxy-secrets create-ssl-proxy-secrets

create-sp-proxy-secrets:
	# Create keys and certs for the sp-proxy service
	@mkdir -p "$(BASE_DIR)/build/secrets/sp-proxy"
	@docker run --rm \
		--user $(shell id -u):$(shell id -g) \
		--volume "$(VOL_BASE)/shib-local/ca/:/src/ca" \
		--volume "$(VOL_BASE)/am-shib/sp-proxy/:/src/sp-proxy/:ro" \
		--volume "$(VOL_BASE)/am-shib/build/secrets/sp-proxy/:/build" \
		--env DOMAIN_NAME="$(DOMAIN_NAME)" \
		--env GENERATE_SSL_CERTS="$(GENERATE_SSL_CERTS)" \
		--workdir "/src/sp-proxy/" \
		rawmind/alpine-base:3.5-1 \
		./create-secrets.sh

create-ssl-proxy-secrets:
	# Create keys and certs for the ssl-proxy service
	@mkdir -p "$(BASE_DIR)/build/secrets/ssl-proxy"
	@docker run --rm \
		--user $(shell id -u):$(shell id -g) \
		--volume "$(VOL_BASE)/shib-local/ca/:/src/ca" \
		--volume "$(VOL_BASE)/am-shib/nginx-ssl/:/src/ssl-proxy/:ro" \
		--volume "$(VOL_BASE)/am-shib/build/secrets/ssl-proxy/:/build" \
		--env DOMAIN_NAME="$(DOMAIN_NAME)" \
		--env GENERATE_SSL_CERTS="$(GENERATE_SSL_CERTS)" \
		--workdir "/src/ssl-proxy/" \
		rawmind/alpine-base:3.5-1 \
		./create-secrets.sh

destroy:
	# Stop containers and remove volumes (include all compose configs because we depend on Archivematica 'qa')
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose down --volumes

list:
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose ps

up:
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose up -d

.PHONY: all bootstrap build clean create-secrets create-sp-proxy-secrets create-ssl-proxy-secrets destroy list up
