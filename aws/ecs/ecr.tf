resource "aws_ecr_repository" "nginx" {
  name = "rdss-archivematica/nginx"
}

resource "aws_ecr_repository" "mcp_server" {
  name = "rdss-archivematica/mcp-server"
}

resource "aws_ecr_repository" "mcp_client" {
  name = "rdss-archivematica/mcp-client"
}

resource "aws_ecr_repository" "automation_tools" {
  name = "rdss-archivematica/automation-tools"
}

resource "aws_ecr_repository" "dashboard" {
  name = "rdss-archivematica/dashboard"
}

resource "aws_ecr_repository" "storage_service" {
  name = "rdss-archivematica/storage-service"
}

resource "aws_ecr_repository" "channel_adapter" {
  name = "rdss-archivematica/channel-adapter"
}

resource "aws_ecr_repository" "nextcloud" {
  name = "rdss-archivematica/nextcloud"
}
