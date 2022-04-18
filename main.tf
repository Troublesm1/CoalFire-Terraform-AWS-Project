# Create vpc
resource "aws_vpc" "coalfire_vpc" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "coalfire-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.coalfire_vpc.id

}

# Create Custom Route Table
resource "aws_route_table" "coal-route-table" {
  vpc_id = aws_vpc.coalfire_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "coalRT"
  }
}

# Create a Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.coalfire_vpc.id
  cidr_block        = "10.1.0.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "coal-subnet-1"
  }
}
resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.coalfire_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "coal-subnet-2"
  }
}
resource "aws_subnet" "subnet-3" {
  vpc_id            = aws_vpc.coalfire_vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "coal-subnet-3"
  }
}
resource "aws_subnet" "subnet-4" {
  vpc_id            = aws_vpc.coalfire_vpc.id
  cidr_block        = "10.1.3.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "coal-subnet-4"
  }
}

# Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.coal-route-table.id
}
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.coal-route-table.id
}
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.subnet-3.id
  route_table_id = aws_route_table.coal-route-table.id
}
resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.subnet-4.id
  route_table_id = aws_route_table.coal-route-table.id
}

# Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "allow Web traffic"
  vpc_id      = aws_vpc.coalfire_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_web"
  }
}

# Create a network interface with an ip in subnet
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-2.id
  private_ips     = ["10.1.1.100"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign an elastic IP to the network interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.1.1.100"
  depends_on                = [aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# Create web server
resource "aws_instance" "web-server-instance" {
  ami               = "ami-0ba62214afa52bec7"
  instance_type     = "t2.micro"
  availability_zone = "us-east-2b"
  key_name          = "Terraform_key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  root_block_device {
    volume_size = "20"
    volume_type = "gp3"
    }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web-server"
  }
}

# Create Network ACL
resource "aws_network_acl" "Public_Net_Acl" {
  vpc_id = aws_vpc.coalfire_vpc.id

  egress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  tags = {
    Name = "public network acl"
  }
}

# Network ACL Association *Public
resource "aws_network_acl_association" "public1" {
  network_acl_id = aws_network_acl.Public_Net_Acl.id
  subnet_id      = aws_subnet.subnet-1.id
}
resource "aws_network_acl_association" "public2" {
  network_acl_id = aws_network_acl.Public_Net_Acl.id
  subnet_id      = aws_subnet.subnet-2.id
}

# Private_Net_Acl
resource "aws_network_acl" "Private_Net_Acl" {
  vpc_id = aws_vpc.coalfire_vpc.id

  egress {
    protocol   = "tcp"
    rule_no    = 210
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  tags = {
    Name = "private network acl"
  }
}

# Network ACL Association *Private
resource "aws_network_acl_association" "private_1" {
  network_acl_id = aws_network_acl.Private_Net_Acl.id
  subnet_id      = aws_subnet.subnet-3.id
}
resource "aws_network_acl_association" "private_2" {
  network_acl_id = aws_network_acl.Private_Net_Acl.id
  subnet_id      = aws_subnet.subnet-4.id
}

# # Create S3 bucket
resource "aws_s3_bucket" "b" {
  bucket = "troublesm-tf-test-bucket"

  tags = {
    Name        = "CoalFire_bucket"
    Environment = "Prod"
  }
}
resource "aws_s3_object" "object_images" {
  bucket = aws_s3_bucket.b.id
  key    = "images/directory/"
}
resource "aws_s3_object" "object_logs" {
  bucket = aws_s3_bucket.b.id
  key    = "Logs/directory/"
}
resource "aws_s3_bucket_lifecycle_configuration" "bucket_configs" {
  bucket = aws_s3_bucket.b.id

  rule {
    id = "rule-1"

    filter {
      prefix = "images/directory/"
    }
    transition {
      days = 90
      storage_class   = "GLACIER"
    }
    status = "Enabled"
  }

  rule {
    id = "rule-2"

    filter {
      prefix = "Logs/directory/"
    }
    expiration {
      days = 90
    }

    status = "Enabled"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.test.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.id
  }
}
# Create Target Group
resource "aws_lb_target_group" "tg" {
  name        = "TargetGroup"
  port        = 80
  target_type = "instance"
  protocol    = "HTTP"
  vpc_id      = aws_vpc.coalfire_vpc.id
}
# # TargetGroup attachment
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "as_conf" {
  name          = "web_config"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_web.id]
  user_data       = <<-EOF
                    #!/bin/bash
                    sudo apt update -y
                    sudo apt install apache2 -y
                    sudo systemctl start apache2
                    sudo bash -c 'echo your first web server in terraform > /var/www/html/index.html'
                    EOF
  root_block_device {
    volume_size = "20"
    volume_type = "gp3"
  }
}

resource "aws_autoscaling_group" "bar" {
#   availability_zones        = ["us-east-2a", "us-east-2b"]
  name                      = "foobar3-terraform-test"
  max_size                  = 6
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.as_conf.name
  vpc_zone_identifier       = [aws_subnet.subnet-3.id, aws_subnet.subnet-4.id]

}

resource "aws_autoscaling_policy" "bat" {
  name                   = "foobar3-terraform-test"
  autoscaling_group_name = aws_autoscaling_group.bar.name
  scaling_adjustment = 1
  adjustment_type = "ExactCapacity"
}


resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
  subnets            = [aws_subnet.subnet-3.id, aws_subnet.subnet-4.id,]
  

  enable_deletion_protection = false

#   access_logs {
#     bucket  = aws_s3_bucket.b.bucket
#     prefix  = "test-lb"
#     enabled = true
#   }

  tags = {
    Environment = "coalfire loadbalancer"
  }
}