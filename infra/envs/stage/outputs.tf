output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "frontend_bucket" {
  value = module.s3.frontend_bucket_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "cluster_name" {
  value = module.ecs.cluster_name
}
