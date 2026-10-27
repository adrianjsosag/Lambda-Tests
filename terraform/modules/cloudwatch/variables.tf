variable "function_name" {
  description = "Nombre de la función Lambda (define el nombre de su log group)"
  type        = string
}

variable "api_name" {
  description = "Nombre del API Gateway (define el nombre del log group de access logs)"
  type        = string
}

variable "retention_in_days" {
  description = "Días de retención de los logs"
  type        = number
  default     = 14
}
