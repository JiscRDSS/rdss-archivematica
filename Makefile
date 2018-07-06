ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

ANSIBLE_PLAYBOOK := $(shell command -v ansible-playbook 2> /dev/null)

# We always want our build to run in non-Jisc mode, i.e. QA mode
ENV ?= qa

VERSION ?= $(shell git describe --tags --always --dirty)

check-ansible-playbook:
ifndef ANSIBLE_PLAYBOOK
	$(error "ansible-playbook is not available, please install Ansible.")
endif

build: build-images

clone: check-ansible-playbook  ## Clone source code repositories.
	ansible-playbook \
		--extra-vars="env=$(ENV) registry=$(REGISTRY)" \
		--tags=clone \
			$(ROOT_DIR)/publish-images-playbook.yml \
			$(ROOT_DIR)/publish-qa-images-playbook.yml

build-images: check-ansible-playbook  ## Build Docker images.
	ansible-playbook \
		--extra-vars="env=$(ENV) registry=$(REGISTRY)" \
		--tags=clone,build \
			$(ROOT_DIR)/publish-images-playbook.yml \
			$(ROOT_DIR)/publish-qa-images-playbook.yml

publish: check-ansible-playbook  ## Publish Docker images to a registry.
	ansible-playbook \
		--extra-vars="env=$(ENV) registry=$(REGISTRY)" \
			$(ROOT_DIR)/publish-images-playbook.yml \
			$(ROOT_DIR)/publish-qa-images-playbook.yml

help:  ## Print this help message.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
