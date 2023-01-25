locals {
  targetgroups = {
    targetgroup1 = {
      
    },
    targetgroup2 = {

    }
  }
}

resource "aws_alb" "circumeo_alb" {
  name               = "circumeo-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = var.SECURITY_GROUPS

  subnets = var.SUBNETS
}

resource "aws_lb_target_group" "circumeo_target_group" {
  for_each = local.targetgroups

  name     = each.key
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.VPC_ID
}

resource "aws_lb_listener" "circumeo_alb_listener" {
  load_balancer_arn = aws_alb.circumeo_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.circumeo_target_group["targetgroup1"].arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "circumeo_alb_test_listener" {
  load_balancer_arn = aws_alb.circumeo_alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.circumeo_target_group["targetgroup2"].arn
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "external_alb_rules" {
  listener_arn = aws_lb_listener.circumeo_alb_listener.arn

  priority = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.circumeo_target_group["targetgroup1"].arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_listener_rule" "external_alb_test_rules" {
  listener_arn = aws_lb_listener.circumeo_alb_test_listener.arn

  priority = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.circumeo_target_group["targetgroup2"].arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
