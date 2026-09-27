terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.62.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my-vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

# The hosted zone already exists at the registrar/Route 53 level. Looking it up
# directly keeps ACM DNS validation independent from the ALB/DNS alias records.
data "aws_route53_zone" "primary" {
  name         = var.domain_name
  private_zone = false
}

module "my-network" {
  source         = "./modules/network"
  vpc_id         = aws_vpc.my-vpc.id
  env_prefix     = var.env_prefix
  az_count       = var.az_count
  vpc_cidr_block = var.vpc_cidr_block
}

module "my-ecr" {
  source     = "./modules/ecr"
  env_prefix = var.env_prefix
}

module "my-iam" {
  source     = "./modules/iam"
  env_prefix = var.env_prefix
}

module "my-ssl" {
  source      = "./modules/ssl"
  domain_name = var.domain_name
}

# ACM DNS validation records are created before the certificate is used by the ALB.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in module.my-ssl.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "cert_gate" {
  certificate_arn         = module.my-ssl.certificate_arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

module "my-alb" {
  source          = "./modules/alb"
  env_prefix      = var.env_prefix
  vpc_id          = aws_vpc.my-vpc.id
  subnet_ids      = module.my-network.public_subnet_ids
  certificate_arn = aws_acm_certificate_validation.cert_gate.certificate_arn
}

module "my-ecs" {
  source                = "./modules/ecs"
  env_prefix            = var.env_prefix
  vpc_id                = aws_vpc.my-vpc.id
  private_subnet_ids    = module.my-network.private_subnet_ids
  az_count              = var.az_count
  alb_security_group_id = module.my-alb.alb_security_group_id
  target_group_arn      = module.my-alb.target_group_arn
  execution_role_arn    = module.my-iam.execution_role_arn
  task_role_arn         = module.my-iam.task_role_arn
  container_image       = "${module.my-ecr.repository_url}:${var.image_tag}"
  domain_name           = var.domain_name
  alb_listener_arn      = module.my-alb.alb_listener_arn
  cpu                   = var.cpu
  memory                = var.memory
  aws_region            = "us-east-1"
}

module "my-dns" {
  source        = "./modules/dns"
  domain_name   = var.domain_name
  env_prefix    = var.env_prefix
  alb_dns_name  = module.my-alb.alb_dns_name
  alb_zone_id   = module.my-alb.alb_hosted_zone_id
}

module "my-monitoring" {
  source           = "./modules/monitoring"
  env_prefix       = var.env_prefix
  ecs_cluster_name = module.my-ecs.ecs_cluster_name
  ecs_service_name = module.my-ecs.ecs_service_name
  alert_email       = var.alert_email
  slack_webhook_url = var.slack_webhook_url
  ecs_log_group_name          = module.my-ecs.log_group_name
  alb_arn_suffix              = module.my-alb.alb_arn_suffix
  target_group_arn             = module.my-alb.target_group_arn
  target_group_arn_suffix      = module.my-alb.target_group_arn_suffix
}
