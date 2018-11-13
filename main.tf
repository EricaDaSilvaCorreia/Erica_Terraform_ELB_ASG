provider "aws" {
  region = "eu-west-1"
}
resource "aws_instance" "app_erica" {
  ami = "${var.app_ami_id}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.subnet_erica.id}"
  vpc_security_group_ids = ["${aws_security_group.sec_group_erica.id}"]
  user_data = "${data.template_file.app_init.rendered}"
  tags {
    Name = "app_${var.name}"
  }
}

resource "aws_subnet" "subnet_erica" {
  vpc_id     = "${var.vpc_id}"
  cidr_block = "10.0.58.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true
  tags {
    Name = "subnet_${var.name}"
  }
}

resource "aws_security_group" "sec_group_erica" {
  name        = "SecGroup_erica"
  description = "Allow all on port 80"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "sec_grp_${var.name}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${var.vpc_id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${data.aws_internet_gateway.default.id}"
  }

  tags{
    Name = "public_rt_${var.name}"
  }
}

resource "aws_route_table_association" "rt_assoc_erica" {
  subnet_id = "${aws_subnet.subnet_erica.id}"
  route_table_id = "${aws_route_table.public.id}"
}

data "aws_internet_gateway" "default" {
  filter {
    name = "attachment.vpc-id"
    values = ["${var.vpc_id}"]
  }
}

data "template_file" "app_init" {
  template = "${file("./scripts/app/init.sh.tpl")}"
}

resource "aws_lb" "Erica_LB" {
  name               = "Erica-LB-TF"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${aws_subnet.subnet_erica.id}"]

  enable_deletion_protection = false

  tags {
    Name = "LB_${var.name}"
    Environment = "production"
  }
}

resource "aws_launch_configuration" "Erica_AutoScaling_conf" {
  name_prefix   = "Erica-ASConf-"
  image_id      = "${var.app_ami_id}"
  instance_type = "t2.micro"
  user_data = "${data.template_file.app_init.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "Erica-AutoScalingGroup" {
  #load_balancers = ["${aws_lb.Erica_LB.id}"]
  name                 = "Erica-AutoScalingGroup"
  launch_configuration = "${aws_launch_configuration.Erica_AutoScaling_conf.name}"
  min_size             = 1
  max_size             = 3
  desired_capacity = 2
  launch_configuration ="${aws_launch_configuration.Erica_AutoScaling_conf.id}"
  vpc_zone_identifier = ["${aws_subnet.subnet_erica.id}"]

  lifecycle {
    create_before_destroy = true
  }
  tag {
    key = "Name"
    value = "${var.name}-AutoScalingGroup-${count.index + 1}"
    propagate_at_launch = true
  }
}
