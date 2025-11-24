variable "environment" {
  type    = string
  default = "stage"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "active_color" {
  type    = string
  default = "blue"
}

variable "backend_image_tag" {
  type    = string
  default = "latest"
}

variable "db_password" {
  type      = string
  sensitive = true
}
