.DEFAULT_GOAL := build

# The environment to build for, one of 'dev' or 'qa'. Defaults to 'qa'.
ENV ?= qa

# The directories to use as part of the docker-compose build. May be a list.
COMPOSE_DIRS ?= $(ENV)

BASE_DIR ?= ${CURDIR}

COMPOSE_PROJECT_NAME ?= rdss

# Paths for Docker named volumes
DATA_DIR ?= /tmp/$(COMPOSE_PROJECT_NAME)
AM_AUTOTOOLS_DATA ?= $(DATA_DIR)/am-autotools-data
AM_PIPELINE_DATA ?= $(DATA_DIR)/am-pipeline-data
ARK_STORAGE_DATA ?= $(DATA_DIR)/arkivum-storage
ELASTICSEARCH_DATA ?= $(DATA_DIR)/elasticsearch-data
JISC_TEST_DATA ?= $(DATA_DIR)/jisc-test-data
MINIO_EXPORT_DATA ?= $(DATA_DIR)/minio-export-data
MYSQL_DATA ?= $(DATA_DIR)/mysql-data
NEXTCLOUD_DATA ?= $(DATA_DIR)/nextcloud-data
NEXTCLOUD_THEMES ?= $(DATA_DIR)/nextcloud-themes
SS_LOCATION_DATA ?= $(DATA_DIR)/am-ss-location-data
SS_STAGING_DATA ?= $(DATA_DIR)/am-ss-staging-data

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
ifeq ("$(ENV)", "dev")
	# Include qa config because dev overrides/extends this
	COMPOSE_FILE_2 := $(shell realpath ${CURDIR}/docker-compose.qa.yml):$(COMPOSE_FILE)
	override COMPOSE_FILE=$(COMPOSE_FILE_2)
endif
export COMPOSE_FILE

# What version are we building?
VERSION ?= $(shell git describe --tags --always --dirty)
export VERSION

all: destroy build create-secrets up bootstrap list

bootstrap create-secrets reset-processing-configs:
	$(foreach DIR, $(COMPOSE_DIRS), $(MAKE) -C $(DIR) $@ ;)

build clean destroy:
	# Process each of the relevant compose dirs
	$(foreach DIR, $(COMPOSE_DIRS), $(MAKE) -C $(DIR) $@ ;)
	@sleep 10

check-vars:
	@echo "ENV = '$(ENV)'"
	@echo "SHIBBOLETH_CONFIG = '$(SHIBBOLETH_CONFIG)'"
	@echo "SHIBBOLETH_IDP = '$(SHIBBOLETH_IDP)'"
	@echo "COMPOSE_DIRS = '$(COMPOSE_DIRS)'"
	@echo "COMPOSE_FILE = '$(COMPOSE_FILE)'"
	@echo "VERSION = '$(VERSION)'"

config:
	docker-compose config

create-volumes:
	# Create Archivematica named volumes
	@mkdir -p $(AM_AUTOTOOLS_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(AM_AUTOTOOLS_DATA) $(COMPOSE_PROJECT_NAME)_am-autotools-data
	@mkdir -p ${AM_PIPELINE_DATA}
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(AM_PIPELINE_DATA) $(COMPOSE_PROJECT_NAME)_am-pipeline-data
	@mkdir -p ${SS_LOCATION_DATA}/automated ${SS_LOCATION_DATA}/interactive
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(SS_LOCATION_DATA) $(COMPOSE_PROJECT_NAME)_am-ss-location-data
	@mkdir -p $(SS_STAGING_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(SS_STAGING_DATA) $(COMPOSE_PROJECT_NAME)_am-ss-staging-data
	# Ensure Archivematica dirs are owned by archivematica (333)
	@chown -R 333:333 $(AM_PIPELINE_DATA) $(SS_LOCATION_DATA) $(SS_STAGING_DATA)
	@chmod -R a=rwX,+t $(SS_LOCATION_DATA)
	# Create Arkivum named volumes
	@mkdir -p $(ARK_STORAGE_DATA)/aipingest
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(ARK_STORAGE_DATA) $(COMPOSE_PROJECT_NAME)_arkivum-storage
	# Create ElasticSearch named volume
	@mkdir -p $(ELASTICSEARCH_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(ELASTICSEARCH_DATA) $(COMPOSE_PROJECT_NAME)_elasticsearch-data
	# Create Jisc named volumes
	@mkdir -p $(JISC_TEST_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(JISC_TEST_DATA) $(COMPOSE_PROJECT_NAME)_jisc-test-research-data
	# Create MINIO named volume
	@mkdir -p $(MINIO_EXPORT_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(MINIO_EXPORT_DATA) $(COMPOSE_PROJECT_NAME)_minio_export_data
	# Create MySQL named volume
	@mkdir -p $(MYSQL_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(MYSQL_DATA) $(COMPOSE_PROJECT_NAME)_mysql_data
	# Create NextCloud named volumes
	@mkdir -p $(NEXTCLOUD_DATA) $(NEXTCLOUD_THEMES)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(NEXTCLOUD_DATA) $(COMPOSE_PROJECT_NAME)_nextcloud-data
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(NEXTCLOUD_THEMES) $(COMPOSE_PROJECT_NAME)_nextcloud-themes

destroy-volumes:
	@echo -n "WARNING! About to delete all data on all volumes! Continue? [yes/no]: " ; \
	read yn ; \
	case "$${yn}" in \
		[Yy][Ee][Ss] ) \
			docker volume rm \
				$(COMPOSE_PROJECT_NAME)_am-autotools-data \
				$(COMPOSE_PROJECT_NAME)_am-pipeline-data \
				$(COMPOSE_PROJECT_NAME)_am-ss-location-data \
				$(COMPOSE_PROJECT_NAME)_am-ss-staging-data \
				$(COMPOSE_PROJECT_NAME)_arkivum-storage \
				$(COMPOSE_PROJECT_NAME)_elasticsearch-data \
				$(COMPOSE_PROJECT_NAME)_jisc-test-research-data \
				$(COMPOSE_PROJECT_NAME)_minio_export_data \
				$(COMPOSE_PROJECT_NAME)_mysql_data \
				$(COMPOSE_PROJECT_NAME)_nextcloud-data \
				$(COMPOSE_PROJECT_NAME)_nextcloud-themes && \
				echo "Removed all Docker volumes. " ; \
			if docker volume list | grep $(COMPOSE_PROJECT_NAME)_ >/dev/null ; then \
				echo "Cannot remove files: docker volumes still in use." ; \
				exit ;\
			else \
				rm -vRf \
					$(AM_AUTOTOOLS_DATA) \
					$(AM_PIPELINE_DATA) \
					$(ARK_STORAGE_DATA) \
					$(ELASTICSEARCH_DATA) \
					$(MINIO_EXPORT_DATA) \
					$(MYSQL_DATA) \
					$(NEXTCLOUD_DATA) \
					$(NEXTCLOUD_THEMES) \
					$(SS_LOCATION_DATA) \
					$(SS_STAGING_DATA) && \
				echo "Removed all files." ; \
			fi ; \
			;; \
		[Nn][Oo] ) \
			;; \
		*) \
			echo "Invalid answer, must be 'yes' or 'no'." ;; \
	esac ; \

list:
	docker-compose ps

up:
	docker-compose up -d

watch:
	docker-compose logs -f

watch-idp:
	docker-compose logs -f idp

watch-nginx:
	docker-compose logs -f nginx

.PHONY: all bootstrap build check-vars clean create-volumes create-secrets config destroy list watch watch-idp watch-nginx up
