terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.20"
    }
  }

  required_version = ">= 1.2.0"

}

provider "aws" {
  region = "ap-southeast-1"
}


#sg
resource "aws_security_group" "instance_sg" {
  name = "instance_security_group"

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# instance 1
resource "aws_instance" "instance_1" {
  ami             = data.aws_ami.ubuntu-2204-ami.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance_sg.name]
  key_name        = "devops_directive_lab_kp"
  user_data       = <<-EOF
                                #!/bin/bash
                                sudo apt update -y
                                sudo apt install apache2 -y
                                sudo systemctl start apache2
                                sudo systemctl enable apache2
                                sudo bash -c "echo your first webserver > /var/www/html/index.html"
                                EOF
}

# instsance 2
resource "aws_instance" "instance_2" {
  ami             = data.aws_ami.ubuntu-2204-ami.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance_sg.name]
  key_name        = "devops_directive_lab_kp"
  user_data       = <<-EOF
                                #!/bin/bash
                                sudo apt update -y
                                sudo apt install apache2 -y
                                sudo systemctl start apache2
                                sudo systemctl enable apache2
                                sudo bash -c "echo your second webserver > /var/www/html/index.html"
                                EOF
}

# S3 bucket

resource "random_string" "random" {
  length           = 16
  special          = true
  override_special = "/@£$"
  lower            = true
}

resource "aws_s3_bucket" "bucket" {
  bucket        = "my-bucket-${lower(random_string.random.result)}"
  force_destroy = true

}


resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}


# load balancer
resource "aws_security_group" "instances_alb_sg" {
  name = "instances-alb-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lb" "load_balancer" {
  name               = "instances-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instances_alb_sg.id]
  subnets            = data.aws_subnets.default_subnet.ids

}

resource "aws_lb_listener" "instances_lb_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn

  port     = "80"
  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_target_group" "instances_lb_target_group" {
  name     = "instance-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "instances_lb_listener_rule" {
  listener_arn = aws_lb_listener.instances_lb_listener.arn

  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances_lb_target_group.arn
  }
}

# attach 2 EC2 to target group
resource "aws_lb_target_group_attachment" "instances_1_attachment" {
  target_group_arn = aws_lb_target_group.instances_lb_target_group.arn
  target_id        = aws_instance.instance_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "instances_2_attachment" {
  target_group_arn = aws_lb_target_group.instances_lb_target_group.arn
  target_id        = aws_instance.instance_2.id
  port             = 80
}


# route53
resource "aws_route53_zone" "primary" {
  name = "stephendevs.io.vn"
}

resource "aws_route53_record" "name" {
  zone_id = aws_route53_zone.primary.zone_id

  name = "stephendevs.io.vn"
  type = "A"

  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_db_instance" "db_instance" {
  identifier          = "db-instance"
  allocated_storage   = 14
  engine              = "postgres"
  engine_version      = "16.2"
  instance_class      = "db.t3.micro"
  db_name             = "mydb"
  username            = "foo"
  password            = "foobarbaz"
  skip_final_snapshot = true
}
