.DEFAULT_GOAL := build

# The directories to use as part of the docker-compose build. May be a list.
COMPOSE_DIRS=dev

BASE_DIR ?= ${CURDIR}

# Local mounted volume paths
AM_PIPELINE_DATA ?= $(BASE_DIR)/vols/am-pipeline-data
SS_DEFAULT_LOCATION_DATA ?= $(BASE_DIR)/../src

# NFS mounted volume paths
NFS_AM_PIPELINE_DATA ?= /am-pipeline-data
NFS_SS_DEFAULT_LOCATION_DATA ?= /am-ss-default-location-data

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

create-local-volumes:
	docker volume create --opt type=none --opt o=bind \
		--opt device=$(AM_PIPELINE_DATA) local_am-pipeline-data
	docker volume create --opt type=none --opt o=bind \
		--opt device=$(SS_DEFAULT_LOCATION_DATA) local_ss-default-location-data

create-nfs-volumes:
	docker volume create --opt type=nfs --opt o=addr=$(NFS_SERVER),rw \
		--opt device=:$(NFS_AM_PIPELINE_DATA) nfs_am-pipeline-data
	docker volume create --opt type=nfs --opt o=addr=$(NFS_SERVER),rw \
		--opt device=:$(NFS_SS_DEFAULT_LOCATION_DATA) nfs_ss-default-location-data

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

.PHONY: all bootstrap build clean create-local-volumes create-nfs-volumes create-secrets config destroy list watch watch-idp watch-nginx up
