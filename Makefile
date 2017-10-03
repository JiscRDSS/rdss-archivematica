ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
AM_BRANCH := "qa/jisc"
SS_BRANCH := "qa/jisc"
AD_BRANCH := "master"

build: build-images

build-images: build-image-dashboard build-image-mcpserver build-image-mcpclient build-image-storage-service build-image-automation-tools build-image-nextcloud

build-image-automation-tools:
	docker build --rm --pull \
		--tag rdss-archivematica-automation-tools:latest \
		-f $(ROOT_DIR)/src/archivematica-automation-tools/Dockerfile \
			$(ROOT_DIR)/src/archivematica-automation-tools/

build-image-dashboard:
	docker build --rm --pull \
		--tag rdss-archivematica-dashboard:latest \
		-f $(ROOT_DIR)/src/archivematica/src/dashboard.Dockerfile \
			$(ROOT_DIR)/src/archivematica/src/

build-image-mcpserver:
	docker build --rm --pull \
		--tag rdss-archivematica-mcpserver:latest \
		-f $(ROOT_DIR)/src/archivematica/src/MCPServer.Dockerfile \
			$(ROOT_DIR)/src/archivematica/src/

build-image-mcpclient:
	docker build --rm --pull \
		--tag rdss-archivematica-mcpclient:latest \
		-f $(ROOT_DIR)/src/archivematica/src/MCPClient.Dockerfile \
			$(ROOT_DIR)/src/archivematica/src/

build-image-nextcloud:
	@cd $(ROOT_DIR)/src/rdss-arkivum-nextcloud/ && make build-files-move-app \
		&& cd .. && \
		docker build --rm --pull \
			--tag rdss-arkivum-nextcloud:latest \
			-f $(ROOT_DIR)/src/rdss-arkivum-nextcloud/Dockerfile \
				$(ROOT_DIR)/src/rdss-arkivum-nextcloud/

build-image-storage-service:
	docker build --rm --pull \
		--tag rdss-archivematica-storage-service:latest \
		-f $(ROOT_DIR)/src/archivematica-storage-service/Dockerfile \
			$(ROOT_DIR)/src/archivematica-storage-service/

clone:
	-git clone --branch $(AM_BRANCH) git@github.com:JiscRDSS/archivematica.git $(ROOT_DIR)/src/archivematica
	-git clone --branch $(SS_BRANCH) git@github.com:JiscRDSS/archivematica-storage-service.git $(ROOT_DIR)/src/archivematica-storage-service
	-git clone --branch $(AD_BRANCH) git@github.com:JiscRDSS/rdss-archivematica-channel-adapter.git $(ROOT_DIR)/src/rdss-archivematica-channel-adapter
	-git clone git@github.com:JiscRDSS/rdss-archivematica-msgcreator.git $(ROOT_DIR)/src/rdss-archivematica-msgcreator
	-git clone --depth 1 --recursive --branch master https://github.com/artefactual/archivematica-sampledata.git $(ROOT_DIR)/src/archivematica-sampledata
	-git clone git@github.com:JiscRDSS/rdss-arkivum-nextcloud.git $(ROOT_DIR)/src/rdss-arkivum-nextcloud
	-git clone --recursive git@github.com:JiscRDSS/rdss-archivematica-automation-tools.git $(ROOT_DIR)/src/rdss-archivematica-automation-tools
