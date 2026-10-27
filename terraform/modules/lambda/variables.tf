variable "function_name" {
  description = "Nombre de la función Lambda"
  type        = string
}

variable "source_dir" {
  description = "Directorio con el código fuente a empaquetar"
  type        = string
}

variable "role_arn" {
  description = "ARN del rol de ejecución"
  type        = string
}

variable "log_group_name" {
  description = "Log group de CloudWatch donde escribe la función"
  type        = string
}

variable "runtime" {
  type    = string
  default = "nodejs22.x"
}

variable "handler" {
  type    = string
  default = "index.handler"
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "timeout" {
  type    = number
  default = 10
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}
