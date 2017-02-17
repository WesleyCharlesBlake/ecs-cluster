#default
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region     = "${var.aws_region}"
}

variable "aws_amis" {
  type = "map"
  default = {
    dev     = "ami-e4e3fd8e"
    staging = "ami-e4e3fd8e"
    prod    = "ami-e4e3fd8e" 
  }
}

#### Networking

data "aws_availability_zones" "available" {}


resource "aws_vpc" "ecs-vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
}

resource "aws_internet_gateway" "ecs-igw" {
    vpc_id = "${aws_vpc.ecs-vpc.id}"
}

resource "aws_subnet" "ecs-public-1" {
    vpc_id             = "${aws_vpc.ecs-vpc.id}"
    cidr_block         = "10.0.1.0/24"
    availability_zone  = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "ecs-public-2" {
    vpc_id             = "${aws_vpc.ecs-vpc.id}"
    cidr_block         = "10.0.2.0/24"
    availability_zone  = "${data.aws_availability_zones.available.names[1]}"
}

resource "aws_route_table" "ecs-public" {
    vpc_id = "${aws_vpc.ecs-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.ecs-igw.id}"
    }
}

resource "aws_route_table_association" "ecs-public" {
    subnet_id      = "${aws_subnet.ecs-public-1.id}"
    route_table_id = "${aws_route_table.ecs-public.id}"
}

resource "aws_route_table_association" "ecs-public-2" {
    subnet_id      = "${aws_subnet.ecs-public-2.id}"
    route_table_id = "${aws_route_table.ecs-public.id}"
}

#### Security

resource "aws_security_group" "ecs-lb-sg" {
  description = "application ELB security group"

  vpc_id = "${aws_vpc.ecs-vpc.id}"
  name   = "tf-ecs-lbsg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}


resource "aws_security_group" "ecs-ec2-sg" {
  description = "ECS EC2 security group"
  vpc_id      = "${aws_vpc.ecs-vpc.id}"
  name        = "ec2-ecs-sec"

  ingress {
    protocol  = "tcp"
    from_port = 8080
    to_port   = 8080

    security_groups = [
      "${aws_security_group.ecs-lb-sg.id}",
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80

    security_groups = [
      "${aws_security_group.ecs-lb-sg.id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#### ALB

resource "aws_alb_target_group" "ecs" {
  name     = "wordpress-ecs"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.ecs-vpc.id}"
}

resource "aws_alb" "ecs-alb" {
  name            = "ecs-alb"
  subnets         = ["${aws_subnet.ecs-public-1.*.id}"]
  security_groups = ["${aws_security_group.ecs-lb-sg.id}"]
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.ecs-alb.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.ecs.id}"
    type             = "forward"
  }
}


#### ECS
resource "aws_ecs_cluster" "wp-ecs" {
  name = "wp-ecs"
}

#### Auto Scaling Launch Config
resource "aws_launch_configuration" "ecs" {
  name                 = "ecs"
  image_id             = "$${var.aws_amis[dev]}"
  instance_type        = "${var.instance_type}"
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.wp-ecs.name} > /etc/ecs/ecs.config"
  key_name             = "${var.key_name}"
  security_groups      = ["${aws_security_group.ecs-ec2-sg.id}"]
}

#### Autoscaling group.
 resource "aws_autoscaling_group" "ecs" {
  name                 = "ecs-asg"
  launch_configuration = "${aws_launch_configuration.ecs.name}"
  min_size             = 1
  max_size             = 10
  desired_capacity     = 1
}

resource "aws_ecs_task_definition" "wordpress" {
  family = "wordpress"
  container_definitions = "${file("task-definitions/wordpress.json")}"
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-east-1b, us-east-1c]"
  }
}

resource "aws_ecs_service" "wordpress" {
  name            = "worpdress"
  name            = "family"
  task_definition = "${aws_ecs_task_definition.wordpress.id}" 
  cluster         = "${aws_ecs_cluster.wp-ecs.id}"
  desired_count   = 2
}


