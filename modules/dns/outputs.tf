output "website_url" {
  value = aws_route53_record.www.fqdn
}

output "root_url" {
    value = aws_route53_record.root.fqdn
}
output "route53_record_name" {
  value = aws_route53_record.www.fqdn
}

output "name_servers" {
  value = data.aws_route53_zone.primary.name_servers
  description = "Use these NS records in your domain registrar's dashboard"
}

output "zone_id" {
  description = "The ID of the Route 53 Hosted Zone created by this module."
  value = data.aws_route53_zone.primary.zone_id
}

output "zone_name" {
  description = "The name of the Route 53 Hosted Zone created by this module."
  value       = data.aws_route53_zone.primary.name
}