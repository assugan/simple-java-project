variable "aws_region" {
  default = "eu-central-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  description = "SSH-key name in AWS"
  default = "ssh-diploma-key"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "allowed_cidr" {
  description = "CIDR for admin access (your public IP /32)"
  type        = string
  default     = "93.109.191.53/32"
}