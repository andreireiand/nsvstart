resource "aws_vpc" "nsv" {
  cidr_block = var.cidr

  tags = {
    Name = "${var.prefix}_VPC"
  }

  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "nsv_subnets" {
  availability_zone     = "eu-west-2a"
  count             = 2 # first subnet {0} is public, second one {1} is private
  vpc_id            = aws_vpc.nsv.id
  cidr_block        = cidrsubnet(aws_vpc.nsv.cidr_block, 8, count.index)

  tags = {
    Name = "${var.prefix}.subnets"
  }
}


resource "aws_internet_gateway" "nsv" {
  vpc_id = aws_vpc.nsv.id

  tags = {
    Name = "${var.prefix}_IG"
  }
}

resource "aws_route_table" "nsv_private" {
  vpc_id = aws_vpc.nsv.id

  tags = {
    Name = "${var.prefix}.inside"
  }
}

resource "aws_route_table" "nsv_public" {
  vpc_id = aws_vpc.nsv.id

  tags = {
    Name = "${var.prefix}.outside"
  }
}

resource "aws_route" "nsv_public" {
  route_table_id         = aws_route_table.nsv_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.nsv.id
}

resource "aws_route_table_association" "nsv_public" {
  subnet_id      = element(aws_subnet.nsv_subnets.*.id, 0) # first subnet is public, second is private
  route_table_id = aws_route_table.nsv_public.id
}

resource "aws_key_pair" "nsv" { # create a key-pair in advance
  key_name   = "nsv"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDiPYI0o3fCzRvPDKhGUSIgSFiKMgzfeeS8f6Ju4TkhnizxiAG19g5GEruHjUfZ1h9DNkwwn4hqG3niicI8Dsn3MAYqNppzt9sa0+DhvFlCkQS1jgH2MvnTu1mMpBNy+/1LDxPyXjbzCtoLmtkFK3Y6/sZebdajld0pgHMH4Ph6/EdTqVNaP9s6Km0QEfBkc5CgTHMDDJGf7zauNW/wQDVFjAn7jGzBfu57U6qQL6VAzhrHl0XZHDV0sDMgf4/ye8k2EpHhbN9bOSJIx+qAkMX+LNhXICpbgwBKWSPYQ+JNHvgvHfobp2CVw6wDiKqsXEU5qmC4ZkQoqZ1jM1djnQoNiR+qmF3phtbn1XemxfJ1qqE3jNs5qO3AsoVKh6bBY16PnFRWPwjxz1jWnGZSayzT+YlTv/S2ctd7TcVKWa8KW+OqY6Pp/aYtY7Z8toFDV11i0mLPRTm+zM6YNDcsSqgynKCcYo4bDEIdOMU8Yn7w160AswHzJe1nRWz/sVhziys= master@ubuntu"
    tags = {
      tag-key = "key_pair_nsv"
  }
}

resource "aws_security_group" "sg_nsv_inside" {
  name        = "sg_nsv_inside"
  description = "Allow All, tighten up this later."
  vpc_id      = aws_vpc.nsv.id

  ingress {
    description = "Allow All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_nsv_inside"
  }
}

resource "aws_security_group" "sg_nsv_outside" {
  name        = "sg_nsv_outside"
  description = "Allow All, tighten up this later."
  vpc_id      = aws_vpc.nsv.id

  ingress {
    description = "Allow All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_nsv_outside"
  }
}

resource "aws_iam_instance_profile" "ssm-iam-profile" {
  name = "ec2_iam_instance_profile"
  role = aws_iam_role.ssm_ec2.name
}

resource "aws_iam_role" "ssm_ec2" {
  name = "ssm_ec2"
  tags = {
      tag-key = "ssm_ec2"
  }

  assume_role_policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":{
    "Effect":"Allow",
    "Principal":{
      "Service":"ec2.amazonaws.com"
    },
    "Action":"sts:AssumeRole"
  }
}
EOF

}

resource "aws_iam_role_policy_attachment" "dev-resources-ssm-policy" {
  role       = aws_iam_role.ssm_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_ec2_profile" {
  name  = "ssm_ec2_profile"
  role = aws_iam_role.ssm_ec2.name
}

resource "aws_instance" "aws_test" {
  ami                   = var.ami_test
  instance_type         = "t2.micro"
  key_name              = "nsv"
  iam_instance_profile  = aws_iam_instance_profile.ssm_ec2_profile.name
  subnet_id             = element(aws_subnet.nsv_subnets.*.id, 1)
  availability_zone     = "eu-west-2a"
  vpc_security_group_ids = [ aws_security_group.sg_nsv_inside.id ]

  tags = {
    Name = "LAN_EC2"
  }
}

# resource "aws_eip" "test" { # no need for this once NSv270 licensed and Allow rule added X0 -> X1
#   vpc       = true
#   count     = 1
#   instance  = aws_instance.aws_test.id

#   tags = {
#     Name = "${var.prefix}_EIP_${count.index}"
#   }
# }

resource "aws_instance" "aws_nsv" {
  ami                   = var.ami_nsv
  instance_type         = "c5.large"
  key_name              = "nsv"
  iam_instance_profile  = aws_iam_instance_profile.ssm_ec2_profile.name
  source_dest_check     = false
  subnet_id             = element(aws_subnet.nsv_subnets.*.id, 0)
  availability_zone     = "eu-west-2a"
  vpc_security_group_ids = [ aws_security_group.sg_nsv_outside.id, aws_security_group.sg_nsv_inside.id ]

  tags = {
    Name = "NSv200"
  }
}

resource "aws_eip" "nsv" {
  vpc       = true
  count     = 1
  instance  = aws_instance.aws_nsv.id

  tags = {
    Name = "${var.prefix}_EIP_${count.index}"
  }
}

resource "aws_network_interface" "inside" {
  subnet_id             = element(aws_subnet.nsv_subnets.*.id, 1)
  source_dest_check     = false
  security_groups       = [ aws_security_group.sg_nsv_inside.id ]
  attachment {
    instance            = aws_instance.aws_nsv.id
    device_index        = 1
  }
}

resource "aws_route" "nsv_private" {
  route_table_id          = aws_route_table.nsv_private.id
  destination_cidr_block  = "0.0.0.0/0"
  network_interface_id    = aws_network_interface.inside.id # this injects NSv's X0 IP as a DG to internal subnet
  #gateway_id             = aws_internet_gateway.nsv.id # this would inject IG as a DG for internal subnet
}

resource "aws_route_table_association" "nsv_private" {
  subnet_id      = element(aws_subnet.nsv_subnets.*.id, 1) # first subnet is public, second is private
  route_table_id = aws_route_table.nsv_private.id
}