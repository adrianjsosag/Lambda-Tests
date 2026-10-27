variable "api_name" {
  description = "Nombre del HTTP API"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN de la Lambda a integrar"
  type        = string
}

variable "lambda_function_name" {
  description = "Nombre de la Lambda (para el permiso de invocación)"
  type        = string
}

variable "route_key" {
  description = "Ruta expuesta, p. ej. \"GET /countdown\""
  type        = string
}

variable "log_group_arn" {
  description = "ARN del log group para access logs"
  type        = string
}

variable "throttling_burst_limit" {
  type    = number
  default = 50
}

variable "throttling_rate_limit" {
  type    = number
  default = 100
}
