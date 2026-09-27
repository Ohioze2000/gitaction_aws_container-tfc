output "target_group_arn" {
  value = aws_lb_target_group.app-tg.arn
}

output "alb_dns_name" {
  value = aws_lb.app-alb.dns_name
}

output "alb_security_group_id" {
  value = aws_security_group.alb-sg.id
}

output "alb_hosted_zone_id" {
  value = aws_lb.app-alb.zone_id
}

output "alb_arn" {
  value = aws_lb.app-alb.arn 
}

output "alb_listener_arn" {
  value = aws_lb_listener.https.arn # or your https listener resource name
}
output "alb_arn_suffix" {
  value = aws_lb.app-alb.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.app-tg.arn_suffix
}
