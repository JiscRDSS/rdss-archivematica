.DEFAULT_GOAL := build

SUB_DIRS := $(sort $(wildcard */))

BASE_DIR ?= ${CURDIR}

VOL_BASE ?= $(BASE_DIR)/..

DEFAULT_COMPOSE_FILE = $(shell realpath ../docker-compose.am-shib.yml)

COMPOSE_FILE ?= "${DEFAULT_COMPOSE_FILE}"

DOMAIN_NAME ?= "example.ac.uk"

LDAP_DOMAIN = $(shell echo -n dc=$(DOMAIN_NAME) | sed 's/[.]/,dc=/g')

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

create-secrets:
	# Create keys and certs for the nginx service
	@mkdir -p "$(BASE_DIR)/build/secrets/nginx"
	@docker run --rm \
		--user $(shell id -u):$(shell id -g) \
		--volume "$(VOL_BASE)/shib-local/ca/:/src/ca" \
		--volume "$(VOL_BASE)/am-shib/nginx/:/src/nginx:ro" \
		--volume "$(VOL_BASE)/am-shib/build/secrets/nginx:/build" \
		--env DOMAIN_NAME="$(DOMAIN_NAME)" \
		--workdir "/src/nginx" \
		rawmind/alpine-base:3.5-1 \
		./create-secrets.sh

destroy:
	# Stop containers and remove volumes (include all compose configs because we depend on Archivematica 'qa')
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose down --volumes

list:
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose ps

up:
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose up -d

.PHONY: all bootstrap build clean create-secrets destroy list up
