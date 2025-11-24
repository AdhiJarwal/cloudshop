variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "target_group_blue_arn" {
  type = string
}

variable "target_group_green_arn" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "backend_image_tag" {
  type    = string
  default = "latest"
}

variable "active_color" {
  type    = string
  default = "blue"
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type = string
}
