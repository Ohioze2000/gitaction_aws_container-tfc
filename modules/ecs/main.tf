# 1. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.env_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }
}

# 2. ECS Task Definition (The Blueprint)
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.env_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn # Role for ECS to pull image
  task_role_arn            = var.task_role_arn      # Role for App to use AWS services

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64" # Or ARM64 if you built it on a Mac
  }

  container_definitions = jsonencode([
    {
      name      = "my-website-app"
      image     = var.container_image # e.g., your ECR URL
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      # Inject variables here!
      environment = [
        { name = "NODE_ENV", value = var.env_prefix },
        { name = "API_ENDPOINT", value = "https://api.${var.domain_name}" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.env_prefix}-app"
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# 3. ECS Service (The Manager)
resource "aws_ecs_service" "main" {
  name            = "${var.env_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.az_count
  launch_type     = "FARGATE"
  platform_version = "1.4.0"
  force_new_deployment = true

  # This setting ensures the service stays running during a deployment
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks_sg.id]
    subnets         = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "my-website-app"
    container_port   = 80
  }

}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${var.env_prefix}-app" # Match your task definition
  retention_in_days = 7                         # Saves money by deleting old logs
}

resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${var.env_prefix}-ecs-tasks-sg"
  description = "Allow inbound traffic from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 80  # Match your container port
    to_port         = 80
    security_groups = [var.alb_security_group_id] # Strict access: Only the ALB
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"] # Required for pulling images and logging
  }

  tags = {
    Name = "${var.env_prefix}-ecs-tasks-sg"
  }
}

output "ecs_sg_id" {
  value = aws_security_group.ecs_tasks_sg.id
}
