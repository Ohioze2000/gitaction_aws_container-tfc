variable "env_prefix" {
  type        = string
  description = "Environment/resource name prefix."
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster to monitor."
}

variable "ecs_service_name" {
  type        = string
  description = "ECS service to monitor."
}

variable "ecs_log_group_name" {
  type        = string
  description = "ECS application log group monitored for application errors."
}

variable "alb_arn_suffix" {
  type        = string
  description = "Application Load Balancer ARN suffix used by CloudWatch dimensions."
}

variable "target_group_arn" {
  type        = string
  description = "Full target group ARN used by the Lambda for unhealthy target inspection."
}

variable "target_group_arn_suffix" {
  type        = string
  description = "Target group ARN suffix used by CloudWatch dimensions."
}

variable "alert_email" {
  type        = string
  description = "Optional email subscription endpoint for runtime alerts."
  default     = null
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack incoming webhook URL supplied by the Terraform Cloud workspace as a sensitive variable."
  sensitive   = true
}

variable "cpu_alarm_threshold" {
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  type        = number
  default     = 80
}

variable "disk_alarm_threshold" {
  type        = number
  default     = 80
}

variable "unhealthy_target_threshold" {
  type        = number
  default     = 1
}

variable "application_error_threshold" {
  type        = number
  default     = 5
}

variable "log_error_pattern" {
  type        = string
  default     = "%ERROR|Error|error|EXCEPTION|Exception|5[0-9][0-9]%"
}
