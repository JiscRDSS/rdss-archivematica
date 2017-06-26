.DEFAULT_GOAL := build

# The directories to use as part of the docker-compose build. May be a list.
COMPOSE_DIRS=dev

BASE_DIR ?= ${CURDIR}

# Paths for Docker named volumes
AM_PIPELINE_DATA ?= /tmp/am-pipeline-data
SS_LOCATION_DATA ?= $(BASE_DIR)/../src
MINIO_EXPORT_DATA ?= $(VOL_BASE)/dev/s3

# Do we want to include any shibboleth services?
SHIBBOLETH_IDP ?= local
ifdef SHIBBOLETH_CONFIG
	ifeq ("$(SHIBBOLETH_CONFIG)", "archivematica")
		override COMPOSE_DIRS += am-shib
	endif
	# Do we need to use our local IdP service?
	ifeq ("$(SHIBBOLETH_IDP)", "local")
		override COMPOSE_DIRS += shib-local
	endif
endif

# Set the docker-compose COMPOSE_FILE env var to include the config from each
# dir in COMPOSE_DIRS
override COMPOSE_FILE ?= $(shell echo \
	"$(foreach DIR, $(COMPOSE_DIRS),${CURDIR}/docker-compose.$(DIR).yml)"\
	| tr ' ' ':')
export COMPOSE_FILE

all: destroy build create-secrets up bootstrap list

bootstrap create-secrets:
	$(foreach DIR, $(COMPOSE_DIRS), $(MAKE) -C $(DIR) $@ ;)

build clean destroy:
	# Process each of the relevant compose dirs
	$(foreach DIR, $(COMPOSE_DIRS), $(MAKE) -C $(DIR) $@ ;)
	@sleep 10

config:
	docker-compose config

create-volumes:
	mkdir -p ${AM_PIPELINE_DATA}
	docker volume create --opt type=none --opt o=bind \
		--opt device=$(AM_PIPELINE_DATA) rdss_am-pipeline-data
	mkdir -p ${SS_LOCATION_DATA}
	docker volume create --opt type=none --opt o=bind \
		--opt device=$(SS_LOCATION_DATA) rdss_am-ss-location-data
	mkdir -p ${MINIO_EXPORT_DATA}
	docker volume create --opt type=none --opt o=bind \
                --opt device=$(MINIO_EXPORT_DATA) rdss_minio_export_data

list:
	docker-compose ps

up:
	docker-compose up -d
	
validate:
	@echo "SHIBBOLETH_CONFIG = $(SHIBBOLETH_CONFIG)"
	@echo "SHIBBOLETH_IDP = $(SHIBBOLETH_IDP)"
	@echo "COMPOSE_DIRS = $(COMPOSE_DIRS)"

watch:
	docker-compose logs -f

watch-idp:
	docker-compose logs -f idp

watch-nginx:
	docker-compose logs -f nginx

.PHONY: all bootstrap build clean create-volumes create-secrets config destroy list watch watch-idp watch-nginx up
