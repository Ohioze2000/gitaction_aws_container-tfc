output "alb_dns" {
  description = "The DNS name of the Application Load Balancer."
  value = module.my-alb.alb_dns_name
}

output "cloudwatch_alarms_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  value       = module.my-monitoring.cloudwatch_alarms_topic_arn
}

output "ecs_service_name" {
  description = "The name of the running ECS Service."
  value       = module.my-ecs.ecs_service_name
}

output "ecs_cluster_name" {
  description = "The name of the ECS Cluster Name"
  value       = module.my-ecs.ecs_cluster_name     # Ensure 'ecs' matches your module name in main.tf
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository to push images to."
  value       = module.my-ecr.repository_url
}

output "website_url" {
  description = "The HTTPS URL of the deployed website."
  value = "https://${var.domain_name}"
}

output "route53_zone_name" {
  description = "The name of the Route 53 Hosted Zone created."
  value       = module.my-dns.zone_name # Common output for a hosted zone's name
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.my-network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.my-network.private_subnet_ids
}

output "validated_certificate_arn" {
  description = "The ARN of the ACM certificate."
  value       = module.my-ssl.certificate_arn 
}

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.my-vpc.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer."
  value       = module.my-alb.alb_arn # Assuming my-alb outputs this
}

output "alb_hosted_zone_id" {
  description = "The Hosted Zone ID of the Application Load Balancer (for Route 53 alias records)."
  value       = module.my-alb.alb_hosted_zone_id # Assuming my-alb outputs this
}

output "route53_zone_id" {
  description = "The ID of the Route 53 Hosted Zone created."
  value       = module.my-dns.zone_id # Assuming my-dns outputs this
}
output "runtime_alert_lambda_arn" {
  description = "Lambda ARN that receives CloudWatch runtime alerts through SNS and sends Slack notifications."
  value       = module.my-monitoring.runtime_alert_lambda_arn
}

