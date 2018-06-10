variable "aws_region" {
	default = "eu-west-1"
}

variable "vpc_cidr" {
	default = "10.0.0.0/16"
}

variable "subnet_cidr" {
	default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "subnet_avail" {
	default = {
		"10.0.1.0/24" = "eu-west-1a"
		"10.0.2.0/24" = "eu-west-1b"
	}
}

variable "key_name" {
	description = "Enter the key value pair name for EC2 instances"
}