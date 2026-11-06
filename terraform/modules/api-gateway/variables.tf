variable "api_name" {
  description = "Nombre del HTTP API"
  type        = string
}

variable "routes" {
  description = "Rutas a publicar: clave => { route_key, lambda_invoke_arn, lambda_function_name }. Una integración, ruta y permiso por clave."
  type = map(object({
    route_key            = string # p. ej. "GET /countdown"
    lambda_invoke_arn    = string
    lambda_function_name = string
  }))

  validation {
    condition     = length(distinct([for r in values(var.routes) : r.route_key])) == length(var.routes)
    error_message = "Los route_key no se pueden repetir."
  }
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
