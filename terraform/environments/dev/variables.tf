variable "region" {
  description = "Región AWS"
  type        = string
}

variable "project" {
  description = "Nombre del proyecto (prefijo de recursos)"
  type        = string
}

variable "environment" {
  description = "Nombre del entorno"
  type        = string
}

variable "log_retention_in_days" {
  type    = number
  default = 14
}
