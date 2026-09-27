variable "vpc_id" {
  type        = string
  description = "VPC where ECS tasks are deployed."
}

variable "env_prefix" {
  type        = string
  description = "Environment/resource name prefix."
}

variable "az_count" {
  type        = number
  description = "Number of ECS tasks to run."
  default     = 2
}

variable "aws_region" {
  type        = string
  description = "AWS region used by the ECS task log driver."
  default     = "us-east-1"
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "container_image" {
  type        = string
  description = "Full ECR image URI with an immutable deployment tag."
}

variable "target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "domain_name" {
  type = string
}

variable "alb_listener_arn" {
  type        = string
  description = "HTTPS listener ARN used to establish the module dependency chain."
}

variable "cpu" {
  type        = string
  description = "Fargate task CPU units."
  default     = "256"
}

variable "memory" {
  type        = string
  description = "Fargate task memory in MiB."
  default     = "512"
}
