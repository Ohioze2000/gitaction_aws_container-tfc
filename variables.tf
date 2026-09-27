variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the application VPC."
}

variable "env_prefix" {
  type        = string
  description = "Environment/resource name prefix."
}

variable "az_count" {
  type        = number
  description = "Number of Availability Zones to use."
  default     = 2
}

variable "my_ip"{
  type = string
  description = "MY IP"
}

variable "domain_name" {
  type        = string
  description = "Existing public root domain name used for Route 53 records and ACM validation."
}

variable "container_port" {
  type    = number
}

variable "cpu" {
  type        = string
  description = "ECS Fargate task CPU units."
  default     = "256"
}

variable "memory" {
  type        = string
  description = "ECS Fargate task memory in MiB."
  default     = "512"
}

variable "image_tag" {
  type        = string
  description = "Existing ECR image tag to deploy. CI/CD supplies the Git commit SHA."
  default     = "latest"
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack incoming webhook URL supplied as a sensitive Terraform Cloud workspace variable."
  sensitive   = true
}

variable "alert_email" {
  type        = string
  description = "Optional email address for CloudWatch/SNS runtime alerts."
  default     = null
}
