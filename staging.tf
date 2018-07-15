terraform {
	required_version = "0.11.7"
}

provider "aws" {
	version = "1.27.0"
	profile = "${var.profile}"
	shared_credentials_file = "${var.shared_credentials_file}"
	region = "${var.region}"
}

resource "aws_vpc" "ci_vpc" {
	cidr_block = "10.0.0.0/16"
	tags {
		Env = "${var.tag_env}"
	}
}

resource "aws_internet_gateway" "ci_vpc_igw" {
	vpc_id = "${aws_vpc.ci_vpc.id}"
}

resource "aws_default_route_table" "ci_vpc_drt" {
	default_route_table_id = "${aws_vpc.ci_vpc.default_route_table_id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.ci_vpc_igw.id}"
	}
}

resource "aws_subnet" "ci_subnet" {
	vpc_id = "${aws_vpc.ci_vpc.id}"
	cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "ci_server_sg" {
	name = "ci-server-sg"
	description = "Security group for CI server to allow inbound connections over SSL"
	vpc_id = "${aws_vpc.ci_vpc.id}"

	egress {
		from_port = 0
		to_port = 0 
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
		from_port = 443
		to_port = 443
		protocol = "tcp"
		cidr_blocks = ["${var.allow_ci_ingress_cidr}"]
	}
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["${var.allow_ci_ingress_cidr}"]
	}

}

data "aws_iam_policy_document" "ci_server_assume_role" {
        statement {
                principals {
                        identifiers = [
                                "ec2.amazonaws.com"
                        ]
                        type = "Service"
                }

                actions = [
                        "sts:AssumeRole"
                ]
        }
}

data "aws_iam_policy_document" "ci_server_ipd" {
        statement {
                sid = "1"
                resources = [
                        "arn:aws:logs:*:*:*"
                ]
                actions = [
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents",
                        "logs:DescribeLogStreams"
                ]
                effect = "Allow"
        }
}

resource "aws_iam_role" "ci_server_ir" {
        name = "ci-server"
        assume_role_policy = "${data.aws_iam_policy_document.ci_server_assume_role.json}"
}

resource "aws_iam_role_policy" "ci_server_rp" {
        name = "ci-server"
        role = "${aws_iam_role.ci_server_ir.name}"
        policy = "${data.aws_iam_policy_document.ci_server_ipd.json}"
}

resource "aws_iam_instance_profile" "ci_server_iip" {
	name = "ci-server"
	role = "${aws_iam_role.ci_server_ir.name}"
}

resource "aws_instance" "ci_server" {
	ami = "ami-ed838091"
	instance_type = "t2.micro"

	iam_instance_profile = "${aws_iam_instance_profile.ci_server_iip.name}"

	tags {
		Name = "ci-server"
	}

	subnet_id = "${aws_subnet.ci_subnet.id}"
	vpc_security_group_ids = ["${aws_security_group.ci_server_sg.id}"]
}

resource "aws_eip" "ci_server_public_ip" {
	instance = "${aws_instance.ci_server.id}"
	vpc = true
}

output "ci_server_private_ip" {
	value = "${aws_instance.ci_server.private_ip}"
	description = "Private IP of CI server"
}

output "ci_server_public_ip" {
	value = "${aws_eip.ci_server_public_ip.public_ip}"
	description = "Public IP of CI server"
}
