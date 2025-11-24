output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_blue_name" {
  value = aws_ecs_service.backend_blue.name
}

# output "service_green_name" {
#   value = aws_ecs_service.backend_green.name
# }

output "ecs_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}
