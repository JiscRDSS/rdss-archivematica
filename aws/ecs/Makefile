TEMPFILE := $(shell mktemp)
IGNORE := $(shell terraform output -json > $(TEMPFILE))

ECR_NGINX_URL = $(shell cat $(TEMPFILE) | jq --raw-output ".ecr_nginx_repository_url.value")
ECR_MCP_SERVER_URL = $(shell cat $(TEMPFILE) | jq --raw-output ".ecr_mcp_server_repository_url.value")
ECR_MCP_CLIENT_URL = $(shell cat $(TEMPFILE) | jq --raw-output ".ecr_mcp_client_repository_url.value")
ECR_AUTOMATION_TOOLS_URL = $(shell cat $(TEMPFILE) | jq --raw-output ".ecr_automation_tools_repository_url.value")
ECR_DASHBOARD_URL = $(shell cat $(TEMPFILE) | jq --raw-output ".ecr_dashboard_repository_url.value")
ECR_STORAGE_SERVICE_URL = $(shell cat $(TEMPFILE) | jq --raw-output ".ecr_storage_service_repository_url.value")
ECR_CHANNEL_ADAPTER_URL = $(shell cat $(TEMPFILE) | jq --raw-output ".ecr_channel_adapter_repository_url.value")
ECR_NEXTCLOUD_URL = $(shell cat $(TEMPFILE) | jq --raw-output ".ecr_nextcloud_repository_url.value")


publish-images: publish-image-nginx publish-image-mcp-server publish-image-mcp-client publish-image-automation-tools publish-image-dashboard publish-image-storage-service publish-image-channel-adapter publish-image-nextcloud

publish-image-nginx:
	@echo "Publishing Docker image: nginx"

publish-image-mcp-server:
	@echo "Publishing Docker image: mcp-server"
	docker build -t "$(ECR_MCP_SERVER_URL):latest" -f ../../src/archivematica/src/MCPServer.Dockerfile ../../src/archivematica/src
	docker push $(ECR_MCP_SERVER_URL)

publish-image-mcp-client:
	@echo "Publishing Docker image: mcp-client"
	docker build -t "$(ECR_MCP_CLIENT_URL):latest" -f ../../src/archivematica/src/MCPClient.Dockerfile ../../src/archivematica/src
	docker push $(ECR_MCP_CLIENT_URL)

publish-image-automation-tools:
	@echo "Publishing Docker image: automation-tools"
	docker build -t "$(ECR_AUTOMATION_TOOLS_URL):latest" ../../src/rdss-archivematica-automation-tools
	docker push $(ECR_AUTOMATION_TOOLS_URL)

publish-image-dashboard:
	@echo "Publishing Docker image: dashboard"
	docker build -t "$(ECR_DASHBOARD_URL):latest" -f ../../src/archivematica/src/dashboard.Dockerfile ../../src/archivematica/src
	docker push $(ECR_DASHBOARD_URL)

publish-image-storage-service:
	@echo "Publishing Docker image: storage-service"
	docker build -t "$(ECR_STORAGE_SERVICE_URL):latest" ../../src/archivematica-storage-service
	docker push $(ECR_STORAGE_SERVICE_URL)

publish-image-channel-adapter:
	@echo "Publishing Docker image: channel-adapter"
	docker build -t "$(ECR_CHANNEL_ADAPTER_URL):latest" ../../src/rdss-archivematica-channel-adapter
	docker push $(ECR_CHANNEL_ADAPTER_URL)

publish-image-nextcloud:
	@echo "Publishing Docker image: nextcloud to $(ECR_NEXTCLOUD_URL)"
	docker build -t "$(ECR_NEXTCLOUD_URL):latest" ../../src/rdss-arkivum-nextcloud
	docker push $(ECR_NEXTCLOUD_URL)
