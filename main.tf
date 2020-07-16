provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}

resource "aws_subnet" "public-a" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "public-a-tf"
  }
}

resource "aws_subnet" "public-b" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "public-b-tf"
  }
}


resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "terraform"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "igw-tf"
  }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "internet-tf"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.r.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public-b.id
  route_table_id = aws_route_table.r.id
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "ec2-key-tf"
  public_key = tls_private_key.example.public_key_openssh
}


resource "aws_security_group" "allow_http" {
  name        = "allow_tls"
  description = "Allow http inbound traffic"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http-tf"
  }
}


#Create loadbalancer
resource "aws_lb" "alb_terraform" {
  name               = "alb-terraform"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.allow_http.id}"]
   subnets           = ["${aws_subnet.public-a.id}, ${aws_subnet.public-b.id}"]
}

#Create target group
resource "aws_lb_target_group" "target_group_tf" {
  name     = "target-group-tf"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}

#Auto-scalling-group
resource "aws_placement_group" "asg_placement_group_terraform" {
  name     = "asg_placement_group_terraform"
  strategy = "cluster"
}

resource "aws_autoscaling_group" "asg_terraform" {
  name                      = "asg_terraform"
  max_size                  = 3
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  placement_group           = aws_placement_group.asg_placement_group_terraform.id
  launch_configuration      = aws_launch_configuration.launch_configuration_terraform.name
  vpc_zone_identifier       = aws_subnet.subnet_1_terraform.id

  initial_lifecycle_hook {
    name                 = "asg_lifecycle_terraform"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 2000
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }

  timeouts {
    delete = "5m"
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_terraform" {
  autoscaling_group_name = aws_autoscaling_group.asg_terraform.id
  alb_target_group_arn   = aws_alb-target_group.lb-target-group-tf.arn
}