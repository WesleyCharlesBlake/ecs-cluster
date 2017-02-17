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


variable "key_name" {
  default = "somekey"
}

variable "instance_type" {
  default = "t2.micro"
}