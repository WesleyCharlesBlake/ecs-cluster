variable "aws_access_key" {
    type = "string"
    description = "Access key"
}

variable "aws_secret_key" {
    type = "string"
    description = "Secret Key"
}

variable "aws_region" {
  description = "The AWS region to create resources in."
  default = "us-east-1"
}

variable "availability_zones" {
  description = "The availability zones"
  default = "us-east-1b"
}


variable "amis" {
  type = "map"
  description = "ECS Container Instances AMIs"
  default = {
    us-east-1      = "ami-b2df2ca4"
    us-east-2      = "ami-832b0ee6"
    us-west-1      = "ami-dd104dbd"
    us-west-2      = "ami-022b9262"
  }
}


variable "instance_type" {
  default = "t2.micro"
}