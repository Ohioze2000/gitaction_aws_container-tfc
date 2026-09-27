# ECS task execution role: used by ECS/Fargate to pull images and publish logs.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.env_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Application task role. It intentionally has no AWS permissions until the
# application requires a specific AWS API; permissions should then be added
# with a least-privilege policy for the required resource(s).
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.env_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_execution_logs_creation" {
  name = "${var.env_prefix}-ecs-logs-creation"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["logs:CreateLogGroup"]
      Effect   = "Allow"
      Resource = "arn:aws:logs:us-east-1:*:log-group:/ecs/${var.env_prefix}-app*"
    }]
  })
}
