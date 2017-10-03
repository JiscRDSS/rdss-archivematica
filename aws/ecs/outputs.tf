output "launch_configuration" {
  value = "${aws_launch_configuration.app.id}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.app.id}"
}

output "ecr_nginx_repository_url" {
  value = "${aws_ecr_repository.nginx.repository_url}"
}

output "ecr_mcp_server_repository_url" {
  value = "${aws_ecr_repository.mcp_server.repository_url}"
}

output "ecr_mcp_client_repository_url" {
  value = "${aws_ecr_repository.mcp_client.repository_url}"
}

output "ecr_automation_tools_repository_url" {
  value = "${aws_ecr_repository.automation_tools.repository_url}"
}

output "ecr_dashboard_repository_url" {
  value = "${aws_ecr_repository.dashboard.repository_url}"
}

output "ecr_storage_service_repository_url" {
  value = "${aws_ecr_repository.storage_service.repository_url}"
}

output "ecr_channel_adapter_repository_url" {
  value = "${aws_ecr_repository.channel_adapter.repository_url}"
}

output "ecr_nextcloud_repository_url" {
  value = "${aws_ecr_repository.nextcloud.repository_url}"
}
