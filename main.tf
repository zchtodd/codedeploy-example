provider "aws" {
  region = "us-east-2"
}

data "template_file" "user_data" {
  template = "${file("user_data.sh")}"
}

locals {
  subnets = {
    public_subnet1 = {
      cidr_block        = "10.1.0.0/24"
      availability_zone = data.aws_availability_zones.available.names[0]
    },
    public_subnet2 = {
      cidr_block        = "10.1.1.0/24"
      availability_zone = data.aws_availability_zones.available.names[1]
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0" 
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_subnet" "public_subnet" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public_subnet["public_subnet1"].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public_subnet["public_subnet2"].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "default" {
  name = "default-sg"

  vpc_id = aws_vpc.vpc.id
  depends_on = [aws_vpc.vpc]

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "ssh-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDWEuPajxRetmLnsRdrCBVJU/hMeG9xILcK+uHofZl4Nfr2PXRHCyqQcwn25DiT3Ory4KczVwzl2x+Bog2mz1o8Ws4xlqyUUfbScZAwIO5yXdqYC9K6X3M7ruKaHqIo+l5CdPoejra8UrVf64P0V0SggyODHGqg1NjGTLDEKEGDUQKOEz7ryZJX1exZvpJfVCsxwaq9bU1EgXnKDAkkAtzN0n7nnG7UIx9ADOnLjfvjwtk7AMmHbeDWq7y4VrTLN5cN2Ifo9QT1yc0aDn8VnxkCK6wrkP6lACrOyDemECAp1z2fEisUqm7EZE47nwAIYNZe8wrWclKR8NpEXr8TvyB/iguyjFrM9NWNeDEQ9uIwIG+Vb3cSKHcu4GBFQBCkeWSoetkk+inYz9OtpuaeToJ8ZrRjBvXckvc/l1TjcIZkRIyJRCkdfUFOLc9LwJ8CvenDWs08kHq3T/0RAViU9ijwn17Psku3faQ3VoY9vIkIHCVzcxZ4oJnOAOzVyHzmjX8= zachtodd@pop-os" 
}

resource "aws_instance" "blue2" {
  ami                  = "ami-0a606d8395a538502"
  instance_type        = "t2.micro"
  subnet_id            = aws_subnet.public_subnet["public_subnet1"].id

  vpc_security_group_ids = [aws_security_group.default.id]

  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.main.name
  user_data_base64            = "${base64encode(data.template_file.user_data.rendered)}"
  user_data_replace_on_change = true

  key_name = "ssh-key"

  tags = {
    InstanceType = "AppServer" 
  }
}

resource "aws_instance" "green2" {
  ami                  = "ami-0a606d8395a538502"
  instance_type        = "t2.small"
  subnet_id            = aws_subnet.public_subnet["public_subnet2"].id

  vpc_security_group_ids = [aws_security_group.default.id]

  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.main.name
  user_data                   = data.template_file.user_data.rendered
  user_data_replace_on_change = true

  key_name = "ssh-key"

  tags = {
    InstanceType = "AppServer" 
  }
}

resource "aws_lb_target_group_attachment" "blue" {
  target_group_arn = module.load_balancer.targetgroup1.arn
  target_id        = aws_instance.blue2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "green" {
  target_group_arn = module.load_balancer.targetgroup2.arn
  target_id        = aws_instance.green2.id
  port             = 80
}

resource "aws_s3_bucket" "codedeploy" {
  bucket = "circumeo-codedeploy"
}

# create a service role for codedeploy
resource "aws_iam_role" "codedeploy_service" {
  name = "codedeploy-service-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "codedeploy.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# attach AWS managed policy called AWSCodeDeployRole
# required for deployments which are to an EC2 compute platform
resource "aws_iam_role_policy_attachment" "codedeploy_service" {
  role       = "${aws_iam_role.codedeploy_service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_iam_role_policy_attachment" "codedeploy_service2" {
  role       = "${aws_iam_role.codedeploy_service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# create a service role for ec2 
resource "aws_iam_role" "instance_profile" {
  name = "codedeploy-instance-profile"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "main" {
  name = "codedeploy-instance-profile"
  role = "${aws_iam_role.instance_profile.name}"
}

# provide ec2 access to s3 bucket to download revision. This role is needed by the CodeDeploy agent on EC2 instances.
resource "aws_iam_role_policy_attachment" "instance_profile_codedeploy" {
  role       = "${aws_iam_role.instance_profile.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

resource "aws_iam_role_policy_attachment" "instance_profile_logging" {
  role       = "${aws_iam_role.instance_profile.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_codedeploy_app" "circumeo_app" {
  name             = "circumeo-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "circumeo_deployment_group" {
  app_name               = aws_codedeploy_app.circumeo_app.name
  deployment_group_name  = "circumeo-deployment-group"
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  service_role_arn       = aws_iam_role.codedeploy_service.arn

  load_balancer_info {
	  target_group_pair_info {
		  prod_traffic_route {
				listener_arns = [module.load_balancer.alb_listener_arn, module.load_balancer.alb_test_listener_arn]
		  }

      target_group {
        name = module.load_balancer.targetgroup1.name
      }

      target_group {
        name = module.load_balancer.targetgroup2.name
      }
		}
	}

  ec2_tag_set {
    ec2_tag_filter {
      key   = "InstanceType"
      type  = "KEY_AND_VALUE"
      value = "AppServer"
    }
  }
}

resource "aws_ec2_serial_console_access" "serial_access" {
  enabled = true
}

module "load_balancer" {
  source          = "./modules/load_balancer"
  VPC_ID          = aws_vpc.vpc.id
  SECURITY_GROUPS = [aws_security_group.default.id]
  SUBNETS         = [aws_subnet.public_subnet["public_subnet1"].id, aws_subnet.public_subnet["public_subnet2"].id]
}

output "blue_ip" {
  value = aws_instance.blue2.public_ip
}

output "green_ip" {
  value = aws_instance.green2.public_ip
}

output "user_data_sh" {
  value = data.template_file.user_data.rendered
}
