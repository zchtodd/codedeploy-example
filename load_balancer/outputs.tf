
output "targetgroup1" {
  value = aws_lb_target_group.circumeo_target_group["targetgroup1"]
}

output "targetgroup2" {
  value = aws_lb_target_group.circumeo_target_group["targetgroup2"]
}

output "alb_listener_arn" {
  value = aws_lb_listener.circumeo_alb_listener.arn
}

output "alb_test_listener_arn" {
  value = aws_lb_listener.circumeo_alb_test_listener.arn
}
