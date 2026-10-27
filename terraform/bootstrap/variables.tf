variable "region" {
  description = "Región AWS"
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Nombre del proyecto (prefijo de recursos)"
  type        = string
  default     = "lambda-tests"
}

variable "force_destroy" {
  description = "Permite borrar el bucket aunque contenga objetos (solo para destruirlo)"
  type        = bool
  default     = false
}
