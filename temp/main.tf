#define the AWS zone
provider aws {
	region = "${var.aws_region}"
}

#create a new VPC
resource "aws_vpc" "tf_vpc" {
	cidr_block = "${var.vpc_cidr}"
	tags = {
		Name = "Terraform-Test"
	}
}

# create internet gateway
resource "aws_internet_gateway" "tf_gw" {
	vpc_id = "${aws_vpc.tf_vpc.id}"
	tags {
		Name = "Terraform-Test"
	}
}

#create 2 subnets
resource "aws_subnet" "tf_subnet" {
	count = 2
	vpc_id = "${aws_vpc.tf_vpc.id}"
	cidr_block = "${var.subnet_cidr[count.index]}"
	availability_zone = "${var.subnet_avail[var.subnet_cidr[count.index]]}"
	tags {
		Name = "Terraform-Test"
	}
}

#create aws route table
resource "aws_route_table" "tf_rt" {
	vpc_id = "${aws_vpc.tf_vpc.id}"

	route {
		cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.tf_gw.id}"
	}
	tags {
		Name = "Terraform-Test"
	}
}

#associate subnets with the route table created
resource "aws_route_table_association" "tf_ra" {
	count = "${aws_subnet.tf_subnet.count}"
    subnet_id      = "${aws_subnet.tf_subnet.*.id[count.index]}"
    route_table_id = "${aws_route_table.tf_rt.id}"
}

#create and associate network ACL to the subnets created
resource "aws_network_acl" "tf_acl" {
  vpc_id = "${aws_vpc.tf_vpc.id}"
  subnet_ids = ["${aws_subnet.tf_subnet.*.id}"]


  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

    ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 60999
  }

    egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 60999
  }

  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  tags {
    Name = "terraform testing"
  }
}

#create Security group
resource "aws_security_group" "tf_sg" {
	name = "Terraform"
	vpc_id = "${aws_vpc.tf_vpc.id}"
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress {
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = -1
		cidr_blocks = ["0.0.0.0/0"]
	}
}

#filter the ami to use
data "aws_ami" "tf_ami" {
	most_recent = true
	owners = ["099720109477"] # canonical
	filter {
		name = "name"
		values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server*"]
	}
}

#template for user_data
data "template_file" "tf_ud" {
	template = "${file("${path.module}/app_install.tpl")}"
	vars {
		app = "apache2"
	}
}

#create AWS instance
resource "aws_instance" "tf_inst" {
	count = 2
	ami = "${data.aws_ami.tf_ami.id}"
	availability_zone = "${aws_subnet.tf_subnet.*.availability_zone[count.index]}"
	instance_type = "t2.micro"
	key_name = "${var.key_name}"
	vpc_security_group_ids = ["${aws_security_group.tf_sg.id}"]
	associate_public_ip_address = true
	subnet_id = "${aws_subnet.tf_subnet.*.id[count.index]}"
	user_data = "${data.template_file.tf_ud.rendered}"
}

#create Load Balancer
resource "aws_elb" "tf_lb" {
	name = "Terraform-LB"
	#availability_zones = ["${aws_instance.tf_inst.*.availability_zone}"]
	subnets = ["${aws_subnet.tf_subnet.*.id}"]
	security_groups = ["${aws_security_group.tf_sg.id}"]
	listener {
		instance_port = 80
		instance_protocol = "tcp"
		lb_port = 80
		lb_protocol = "tcp"
	}
	instances = ["${aws_instance.tf_inst.*.id}"]
	cross_zone_load_balancing   = true
    idle_timeout                = 400
    connection_draining         = true
    connection_draining_timeout = 400
	health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 30
  }


}