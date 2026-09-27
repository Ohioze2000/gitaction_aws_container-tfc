resource "aws_sns_topic" "alerts" {
  name         = "${var.env_prefix}-runtime-alerts"
  display_name = "${var.env_prefix} Runtime Alerts"

  tags = {
    Name = "${var.env_prefix}-runtime-alerts"
  }
}


resource "aws_iam_role" "lambda" {
  name = "${var.env_prefix}-runtime-alert-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.env_prefix}-runtime-alert-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:*:*"
      },
      {
        Effect = "Allow"
        Action = ["ecs:DescribeServices"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:DescribeTargetHealth"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.env_prefix}-runtime-alert"
  retention_in_days = 14
}

resource "aws_lambda_function" "runtime_alert" {
  function_name    = "${var.env_prefix}-runtime-alert"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = "${path.module}/lambda/runtime-alert.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/runtime-alert.zip")
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      ECS_CLUSTER_NAME = var.ecs_cluster_name
      ECS_SERVICE_NAME = var.ecs_service_name
      ENV_PREFIX       = var.env_prefix
      TARGET_GROUP_ARN = var.target_group_arn
      AWS_REGION       = "us-east-1"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}


resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.runtime_alert.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.runtime_alert.arn
}

resource "aws_sns_topic_subscription" "email_subscription" {
  count     = var.alert_email == null ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.env_prefix}-High-CPU-Utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "ECS service CPU utilization is above the configured threshold."
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.env_prefix}-High-Memory-Utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "ECS service memory utilization is above the configured threshold."
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.env_prefix}-Unhealthy-ALB-Targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.unhealthy_target_threshold
  alarm_description   = "Application Load Balancer has one or more unhealthy targets."
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_disk" {
  alarm_name          = "${var.env_prefix}-High-Disk-Utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TaskEphemeralStorageUtilization"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.disk_alarm_threshold
  alarm_description   = "ECS Fargate task ephemeral storage utilization is above the configured threshold."
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${var.env_prefix}-Application-Errors"
  log_group_name = var.ecs_log_group_name
  pattern        = var.log_error_pattern

  metric_transformation {
    name      = "${var.env_prefix}-ApplicationErrorCount"
    namespace = "Custom/ECSApplication"
    value        = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "${var.env_prefix}-Application-Errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "${var.env_prefix}-ApplicationErrorCount"
  namespace           = "Custom/ECSApplication"
  period              = 60
  statistic           = "Sum"
  threshold           = var.application_error_threshold
  alarm_description   = "Application error log events reached the configured threshold."
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.application_errors]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.env_prefix}-ECS-Runtime-Observability"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 8, height = 6,
        properties = {
          metrics = [["AWS/ECS", "CPUUtilization", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name]]
          period = 60, stat = "Average", region = "us-east-1", title = "CPU Utilization (%)", view = "timeSeries"
        }
      },
      {
        type = "metric", x = 8, y = 0, width = 8, height = 6,
        properties = {
          metrics = [["AWS/ECS", "MemoryUtilization", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name]]
          period = 60, stat = "Average", region = "us-east-1", title = "Memory Utilization (%)", view = "timeSeries"
        }
      },
      {
        type = "metric", x = 16, y = 0, width = 8, height = 6,
        properties = {
          metrics = [["ECS/ContainerInsights", "TaskEphemeralStorageUtilization", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name]]
          period = 60, stat = "Average", region = "us-east-1", title = "Ephemeral Disk Utilization (%)", view = "timeSeries"
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 8, height = 6,
        properties = {
          metrics = [["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix]]
          period = 60, stat = "Maximum", region = "us-east-1", title = "Unhealthy ALB Targets", view = "timeSeries"
        }
      },
      {
        type = "metric", x = 8, y = 6, width = 8, height = 6,
        properties = {
          metrics = [["Custom/ECSApplication", "${var.env_prefix}-ApplicationErrorCount"]]
          period = 60, stat = "Sum", region = "us-east-1", title = "Application Errors", view = "timeSeries"
        }
      }
    ]
  })
}
