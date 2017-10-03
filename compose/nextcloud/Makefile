.DEFAULT_GOAL := build

BASE_DIR ?= ${CURDIR}

VOL_BASE ?= $(BASE_DIR)/..

DEFAULT_COMPOSE_FILE = $(shell realpath ../docker-compose.nextcloud.yml)

COMPOSE_FILE ?= "${DEFAULT_COMPOSE_FILE}"

all: build

# Nothing to do for these goals
bootstrap clean create-secrets:

build:
	# Make sure NextCloud files-move app is built
	@cd $(BASE_DIR)/../../src/rdss-arkivum-nextcloud/ && \
		make build-files-move-app && cd $(BASE_DIR)

destroy:
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose down --volumes

list:
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose ps

up:
	COMPOSE_FILE=$(COMPOSE_FILE) docker-compose up -d

.PHONY: all bootstrap build build-files_mv clean create-secrets destroy list up
