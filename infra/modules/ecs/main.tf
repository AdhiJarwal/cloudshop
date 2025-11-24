resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"
  tags = {
    Environment = var.environment
  }
}

resource "aws_security_group" "ecs_tasks" {
  name   = "${var.environment}-ecs-tasks-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "backend_blue" {
  name              = "/ecs/${var.environment}/backend-blue"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "backend_green" {
  name              = "/ecs/${var.environment}/backend-green"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "backend_blue" {
  family                   = "${var.environment}-backend-blue"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name  = "backend"
    image = "${var.ecr_repository_url}:${var.backend_image_tag}"
    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_user },
      { name = "DB_PASSWORD", value = var.db_password }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.environment}/backend-blue"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "backend_green" {
  family                   = "${var.environment}-backend-green"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name  = "backend"
    image = "${var.ecr_repository_url}:${var.backend_image_tag}"
    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_user },
      { name = "DB_PASSWORD", value = var.db_password }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.environment}/backend-green"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "backend_blue" {
  name            = "${var.environment}-backend-blue"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_blue.arn
  desired_count   = var.active_color == "blue" ? 1 : 0
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = var.target_group_blue_arn
    container_name   = "backend"
    container_port   = 8000
  }
  depends_on = [var.alb_listener_arn]
}

# Green service created only when needed for blue/green deployment
# resource "aws_ecs_service" "backend_green" {
#   name            = "${var.environment}-backend-green"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.backend_green.arn
#   desired_count   = var.active_color == "green" ? 1 : 0
#   launch_type     = "FARGATE"
#   network_configuration {
#     subnets          = var.subnet_ids
#     security_groups  = [aws_security_group.ecs_tasks.id]
#     assign_public_ip = true
#   }
#   load_balancer {
#     target_group_arn = var.target_group_green_arn
#     container_name   = "backend"
#     container_port   = 8000
#   }
#   depends_on = [var.alb_listener_arn]
# }
