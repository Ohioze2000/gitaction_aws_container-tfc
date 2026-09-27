output "cloudwatch_alarms_topic_arn" {
  description = "SNS topic ARN used by runtime CloudWatch alarms."
  value       = aws_sns_topic.alerts.arn
}

output "runtime_alert_lambda_arn" {
  description = "Lambda ARN that receives SNS runtime alerts and sends Slack notifications."
  value       = aws_lambda_function.runtime_alert.arn
}

