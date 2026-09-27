output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.main.name
}

output "ecs_task_security_group_id" {
  value = aws_security_group.ecs_tasks_sg.id
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs_log_group.name
}
