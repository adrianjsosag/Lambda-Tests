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
  description = "Días de retención de los log groups (Lambdas y API)"
  type        = number
  default     = 14
}

variable "lambdas" {
  description = <<-EOT
    Funciones Lambda a desplegar. La clave es el nombre de la carpeta en
    lambdas/<clave> y el sufijo de los recursos (<project>-<environment>-<clave>).
    Cada función se publica en el API compartido con su route_key.
  EOT
  type = map(object({
    route_key             = string # p. ej. "GET /countdown"
    runtime               = optional(string, "nodejs22.x")
    handler               = optional(string, "index.handler")
    memory_size           = optional(number, 128)
    timeout               = optional(number, 10)
    environment_variables = optional(map(string), {})
  }))

  validation {
    condition     = length(var.lambdas) > 0
    error_message = "Declara al menos una función en 'lambdas'."
  }

  validation {
    condition     = alltrue([for k in keys(var.lambdas) : can(regex("^[a-z0-9-]+$", k))])
    error_message = "Las claves de 'lambdas' solo pueden tener minúsculas, números y guiones (coinciden con la carpeta lambdas/<clave>)."
  }

  validation {
    condition     = length(distinct([for l in values(var.lambdas) : l.route_key])) == length(var.lambdas)
    error_message = "Cada función debe tener un route_key distinto."
  }
}
