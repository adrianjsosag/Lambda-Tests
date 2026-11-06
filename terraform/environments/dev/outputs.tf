output "api_endpoint" {
  description = "URL base del API compartido"
  value       = module.api_gateway.api_endpoint
}

output "api_urls" {
  description = "URL pública de cada función (clave => URL). Las rutas con parámetros ({id}) se muestran tal cual."
  value = {
    for k, cfg in var.lambdas :
    k => "${module.api_gateway.api_endpoint}${split(" ", cfg.route_key)[1]}"
  }
}

output "lambda_function_names" {
  description = "Nombre en AWS de cada función (clave => nombre)"
  value       = { for k, m in module.lambda : k => m.function_name }
}

output "lambda_log_groups" {
  description = "Log group de cada función (clave => log group)"
  value       = module.cloudwatch.lambda_log_group_names
}

output "api_log_group" {
  description = "Log group de los access logs del API"
  value       = module.cloudwatch.api_log_group_name
}
