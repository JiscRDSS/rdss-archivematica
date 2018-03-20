.DEFAULT_GOAL := build

# The environment to build for, one of 'dev' or 'qa'. Defaults to 'qa'.
ENV ?= qa

# The directories to use as part of the docker-compose build. May be a list.
COMPOSE_DIRS ?= $(ENV)

BASE_DIR ?= ${CURDIR}

# Paths for Docker named volumes
AM_AUTOTOOLS_DATA ?= /tmp/rdss/am-autotools-data
AM_PIPELINE_DATA ?= /tmp/rdss/am-pipeline-data
ARK_STORAGE_DATA ?= /tmp/rdss/arkivum-storage
ELASTICSEARCH_DATA ?= /tmp/rdss/elasticsearch-data
JISC_TEST_DATA ?= /tmp/rdss/jisc-test-data
MINIO_EXPORT_DATA ?= /tmp/rdss/minio-export-data
MYSQL_DATA ?= /tmp/rdss/mysql-data
NEXTCLOUD_DATA ?= /tmp/rdss/nextcloud-data
NEXTCLOUD_THEMES ?= /tmp/rdss/nextcloud-themes
SS_LOCATION_DATA ?= /tmp/rdss/am-ss-location-data
SS_STAGING_DATA ?= /tmp/rdss/am-ss-staging-data

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
		--opt device=$(AM_AUTOTOOLS_DATA) rdss_am-autotools-data
	@mkdir -p ${AM_PIPELINE_DATA}
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(AM_PIPELINE_DATA) rdss_am-pipeline-data
	@mkdir -p ${SS_LOCATION_DATA}/automated ${SS_LOCATION_DATA}/interactive
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(SS_LOCATION_DATA) rdss_am-ss-location-data
	@mkdir -p $(SS_STAGING_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(SS_STAGING_DATA) rdss_am-ss-staging-data
	# Ensure Archivematica dirs are owned by archivematica (333)
	@chown -R 333:333 $(AM_PIPELINE_DATA) $(SS_LOCATION_DATA) $(SS_STAGING_DATA)
	@chmod -R a=rwX,+t $(SS_LOCATION_DATA)
	# Create Arkivum named volumes
	@mkdir -p $(ARK_STORAGE_DATA)/aipingest
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(ARK_STORAGE_DATA) rdss_arkivum-storage
	# Create ElasticSearch named volume
	@mkdir -p $(ELASTICSEARCH_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(ELASTICSEARCH_DATA) rdss_elasticsearch-data
	# Create Jisc named volumes
	@mkdir -p $(JISC_TEST_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(JISC_TEST_DATA) rdss_jisc-test-research-data
	# Create MINIO named volume
	@mkdir -p $(MINIO_EXPORT_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(MINIO_EXPORT_DATA) rdss_minio_export_data
	# Create MySQL named volume
	@mkdir -p $(MYSQL_DATA)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(MYSQL_DATA) rdss_mysql_data
	# Create NextCloud named volumes
	@mkdir -p $(NEXTCLOUD_DATA) $(NEXTCLOUD_THEMES)
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(NEXTCLOUD_DATA) rdss_nextcloud-data
	@docker volume create --opt type=none --opt o=bind \
		--opt device=$(NEXTCLOUD_THEMES) rdss_nextcloud-themes

destroy-volumes:
	@echo -n "WARNING! About to delete all data on all volumes! Continue? [yes/no]: " ; \
	read yn ; \
	case "$${yn}" in \
		[Yy][Ee][Ss] ) \
			docker volume rm \
				rdss_am-autotools-data \
				rdss_am-pipeline-data \
				rdss_am-ss-location-data \
				rdss_am-ss-staging-data \
				rdss_arkivum-storage \
				rdss_elasticsearch-data \
				rdss_jisc-test-research-data \
				rdss_minio_export_data \
				rdss_mysql_data \
				rdss_nextcloud-data \
				rdss_nextcloud-themes && \
				echo "Removed all Docker volumes. " ; \
			if docker volume list | grep rdss_ >/dev/null ; then \
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
