provider "aws" {
    region = var.region_name
  
}

//create a VPC

resource "aws_vpc" "citi_vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "citibank-vpc"
  }
}

//creating subnets
resource "aws_subnet" "sub1" {
  vpc_id            = aws_vpc.citi_vpc.id
  cidr_block        = var.sub1_cidr
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public-Subnet-1"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id            = aws_vpc.citi_vpc.id
  cidr_block        = var.sub2_cidr
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public-Subnet-2"
  }
}

resource "aws_subnet" "sub3" {
  vpc_id            = aws_vpc.citi_vpc.id
  cidr_block        = var.sub3_cidr
  availability_zone = "us-east-1c"

  tags = {
    Name = "Public-Subnet-3"
  }
}

resource "aws_subnet" "subnet4" {
  vpc_id     = aws_vpc.citi_vpc.id
  cidr_block = var.sub4_cidr
  availability_zone = "us-east-1d"
  
  tags = {
    Name = "Public-Subnet-4"
  }
}

//Allocate EIP

resource "aws_eip" "my_eip" {
  vpc = true
}

//Create NAT Gateway
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.subnet4.id

  tags = {
    Name = "citibank-NAT-GW"
  }
}

//create a IGW

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.citi_vpc.id

  tags = {
    Name = "IGW"
  }
}

//create a public route table
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.citi_vpc.id

  route {
    cidr_block = var.IGW
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "Citibank_Pub_route_table"
  }
}

//create private route table

resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.citi_vpc.id

  route {
    cidr_block     = var.ngw_cidr
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
  tags = {
    Name = "citibank_private_rt_table"
  }
}

//subnet association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.sub3.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "pri_asso" {
  subnet_id      = aws_subnet.subnet4.id
  route_table_id = aws_route_table.pri_rt.id
}

//create a EC2 instance

resource "aws_instance" "web_server1" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.my_sg.id]
  subnet_id                   = aws_subnet.sub1.id
  user_data                   = file("./scripts/apache.sh")

  tags = {
    Name     = "Citibank-EC2-Instance"
    
  }
}

// create security group for ec2 instance

resource "aws_security_group" "my_sg" {
  name = "test-sg"
  description = "test security group"
  vpc_id      = aws_vpc.citi_vpc.id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description      = lookup(ingress.value, "description", null)
      from_port        = lookup(ingress.value, "from_port", null)
      to_port          = lookup(ingress.value, "to_port", null)
      protocol         = lookup(ingress.value, "protocol", null)
      cidr_blocks      = lookup(ingress.value, "cidr_blocks", null)
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test-sg"
  }
}

//AMI LC
resource "aws_ami_from_instance" "ami" {
  name               = "terraform-ami-lc"
  source_instance_id = var.source_instance_id
}

//creating launch configuration
resource "aws_launch_configuration" "as_conf" {
  name                        = "lc-asg"
  image_id                    = aws_ami_from_instance.ami.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  security_groups             = [aws_security_group.my_sg.id]
  key_name                    = var.key_name
  #   tags = {
  #     Name = "lc-demo-asg"
  #   }

}

//create clb
resource "aws_elb" "elb_demo" {
  name            = "terraform-elb"
  security_groups = [aws_security_group.my_sg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id, aws_subnet.sub3.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  #instances               = [aws_instance.web_server1.id, aws_instance.web_server2.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "terraform-elb"
  }
}

//create TG
resource "aws_lb_target_group" "vsglobal_tg" {
  name        = "terraform-vsglobal-elb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.citi_vpc.id
}

//create ASG
resource "aws_autoscaling_group" "citi_asg" {
  name                      = "asg-demo"
  max_size                  = 0
  min_size                  = 0
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 0
  launch_configuration = aws_launch_configuration.as_conf.name
  vpc_zone_identifier  = [aws_subnet.sub1.id, aws_subnet.sub2.id, aws_subnet.sub3.id]
   load_balancers       = [aws_elb.elb_demo.id]

  tag {
    key                 = "Name"
    value               = "asg-demo"
    propagate_at_launch = true
  }

    timeouts {
      delete = "15m"
    }

    tag {
      key                 = "lorem"
      value               = "ipsum"
      propagate_at_launch = false
    }
}

//create RDS
resource "aws_db_instance" "default" {
  allocated_storage    = 5
  db_name              = var.db_name
  engine               = var.engine_name
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  username             = var.username
  password             = "${file("../rds-pass.txt")}"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}



