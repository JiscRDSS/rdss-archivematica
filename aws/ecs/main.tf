provider "aws" {
  region = "${var.aws_region}"
}

## Route53

resource "aws_route53_zone" "primary" {
  name       = "rdss-archivematica.test"
  vpc_id     = "${aws_vpc.main.id}"
  vpc_region = "${var.aws_region}"
}

## Kinesis

resource "aws_kinesis_stream" "main" {
  name             = "main"
  shard_count      = 1
  retention_period = 24
}

resource "aws_kinesis_stream" "error" {
  name             = "error"
  shard_count      = 1
  retention_period = 24
}

resource "aws_kinesis_stream" "invalid" {
  name             = "invalid"
  shard_count      = 1
  retention_period = 24
}

## EC2

### EC2 » Network

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "main" {
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "a" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.main.*.id, count.index)}"
  route_table_id = "${aws_route_table.r.id}"
}

### EC2 » Compute

resource "aws_autoscaling_group" "app" {
  name                 = "asg"
  vpc_zone_identifier  = ["${aws_subnet.main.*.id}"]
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  desired_capacity     = "${var.asg_desired}"
  launch_configuration = "${aws_launch_configuration.app.name}"
}

resource "aws_launch_configuration" "app" {
  key_name                    = "${aws_key_pair.auth.id}"
  image_id                    = "${lookup(var.ecs_optimized_amis, var.aws_region)}"
  instance_type               = "${var.instance_type}"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.app.name}"
  security_groups             = ["${aws_security_group.instance_sg.id}"]

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<EOF
#!/bin/bash

echo ECS_CLUSTER=${aws_ecs_cluster.main.name} > /etc/ecs/ecs.config

yum install -y wget

wget https://github.com/awslabs/service-discovery-ecs-dns/releases/download/1.2/ecssd_agent -O /usr/local/bin/ecssd_agent
chmod 755 /usr/local/bin/ecssd_agent

wget https://raw.githubusercontent.com/awslabs/service-discovery-ecs-dns/1.2/ecssd_agent.conf -O /etc/init/ecssd_agent.conf
chmod 644 /etc/init/ecssd_agent.conf
initctl reload-configuration

start ecssd_agent
EOF
}

### EC2 » Security

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_security_group" "lb_sg" {
  description = "Controls access to the application ALB"
  vpc_id      = "${aws_vpc.main.id}"
  name         = "ecs-lb-sg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8000
    to_port     = 8000
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_sg" {
  description = "Controls direct access to application instances"
  vpc_id      = "${aws_vpc.main.id}"
  name        = "ecs-inst-sg"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = "${var.admin_cidr_ingress}"
  }

  ingress {
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
    security_groups = ["${aws_security_group.lb_sg.id}"]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
    security_groups = ["${aws_security_group.lb_sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## ECR

resource "aws_ecr_repository" "nginx" {
  name = "rdss-archivematica/nginx"
}

resource "aws_ecr_repository" "mcp_server" {
  name = "rdss-archivematica/mcp-server"
}

resource "aws_ecr_repository" "mcp_client" {
  name = "rdss-archivematica/mcp-client"
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

## ECS

resource "aws_ecs_cluster" "main" {
  name = "rdss-archivematica"
}

### ECS » RDSS Archivematica Channel Adapter

data "template_file" "task_definition_channel_adapter" {
  template = "${file("${path.module}/tasks/rdss-archivematica-channel-adapter.json")}"

  vars {
    image_url        = "${aws_ecr_repository.channel_adapter.repository_url}:latest"
    container_name   = "rdss-archivematica-channel-adapter"
    log_group_region = "${var.aws_region}"
    log_group_name   = "${aws_cloudwatch_log_group.archivematica.name}"
  }
}

resource "aws_ecs_task_definition" "rdss_archivematica_channel_adapter" {
  family                = "rdss-archivematica-channel-adapter"
  container_definitions = "${data.template_file.task_definition_channel_adapter.rendered}"
}

# resource "aws_ecs_service" "rdss_archivematica_channel_adapter" {
#   name            = "rdss-archivematica-channel-adapter"
#   cluster         = "${aws_ecs_cluster.main.id}"
#   task_definition = "${aws_ecs_task_definition.rdss_archivematica_channel_adapter.arn}"
#   desired_count   = 1
#   depends_on      = ["aws_iam_role_policy.ecs_service"]
# }

### ECS » Redis

data "template_file" "task_definition_redis" {
  template = "${file("${path.module}/tasks/redis.json")}"

  vars {
    image_url        = "redis:3.2-alpine"
    container_name   = "redis"
    log_group_region = "${var.aws_region}"
    log_group_name   = "${aws_cloudwatch_log_group.archivematica.name}"
  }
}

resource "aws_ecs_task_definition" "redis" {
  family                = "redis"
  container_definitions = "${data.template_file.task_definition_redis.rendered}"
}

resource "aws_ecs_service" "redis" {
  name            = "redis"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.redis.arn}"
  desired_count   = 1
  depends_on      = ["aws_iam_role_policy.ecs_service"]
}

## IAM

resource "aws_iam_role" "ecs_service" {
  name = "ecs_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "ecs_service_policy"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "app" {
  name = "ecs-instance-profile"
  role = "${aws_iam_role.app_instance.name}"
}

resource "aws_iam_role" "app_instance" {
  name = "ecs-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = "${file("${path.module}/instance-profile-policy.json")}"

  vars {
    app_log_group_arn = "${aws_cloudwatch_log_group.archivematica.arn}"
    ecs_log_group_arn = "${aws_cloudwatch_log_group.ecs.arn}"
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "TfEcsExampleInstanceRole"
  role   = "${aws_iam_role.app_instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

## ALB

resource "aws_alb" "main" {
  name            = "rdss-archivematica-alb-ecs"
  subnets         = ["${aws_subnet.main.*.id}"]
  security_groups = ["${aws_security_group.lb_sg.id}"]
}

### ALB » Dashboard

resource "aws_alb_target_group" "dashboard" {
  name     = "dashboard"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_alb_listener" "dashboard" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.dashboard.id}"
    type             = "forward"
  }
}

### ALB » Storage Service

resource "aws_alb_target_group" "storage_service" {
  name     = "storage-service"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
}

resource "aws_alb_listener" "storage_service" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.storage_service.id}"
    type             = "forward"
  }
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "archivematica" {
  name = "archivematica"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name = "ecs-agent"
}
