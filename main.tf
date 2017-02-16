#default
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

variable "aws_amis" {
  type = "map"
  default = {
    us-east-1 = "ami-e4e3fd8e"
  }
}

#### Networking

resource "aws_vpc" "ecs-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
}

resource "aws_internet_gateway" "ecs-igw" {
    vpc_id = "${aws_vpc.ecs-vpc.id}"
}

resource "aws_subnet" "ecs-public" {
    vpc_id = "${aws_vpc.ecs-vpc.id}"
    cidr_block = "10.0.1.0/24"
    availability_zones = "${var.availability_zones}"
}

resource "aws_route_table" "ecs-public" {
    vpc_id = "${aws_vpc.ecs-vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.ecs-igw.id}"
    }
}

resource "aws_route_table_association" "ecs-public" {
    subnet_id = "${aws_subnet.ecs-public.id}"
    route_table_id = "${aws_route_table.ecs-public.id}"
}


#### ECS
resource "aws_ecs_cluster" "wp-ecs" {
  name = "wp-ecs"
}

#### Auto Scaling Launch Config
resource "aws_launch_configuration" "ecs" {
  name                 = "ecs"
  image_id             = "${var.amis}"
  instance_type        = "${var.instance_type}"
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.wp-ecs.name} > /etc/ecs/ecs.config"
}

#### Autoscaling group.
 resource "aws_autoscaling_group" "ecs" {
  name                 = "ecs-asg"
  availability_zones   = ["${split(",", var.availability_zones)}"]
  launch_configuration = "${aws_launch_configuration.ecs.name}"
  /* @todo - variablize */
  min_size             = 1
  max_size             = 10
  desired_capacity     = 1
}



