output "api_url" {
  description = "URL pública de la función"
  value       = "${module.api_gateway.api_endpoint}/countdown"
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "lambda_log_group" {
  value = module.cloudwatch.lambda_log_group_name
}
