variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "cloudshop"
}

variable "db_user" {
  type    = string
  default = "cloudshop_admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}
