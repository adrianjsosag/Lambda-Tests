output "lambda_log_group_names" {
  description = "Mapa clave => nombre del log group de cada Lambda"
  value       = { for k, lg in aws_cloudwatch_log_group.lambda : k => lg.name }
}

output "api_log_group_arn" {
  value = aws_cloudwatch_log_group.api.arn
}

output "api_log_group_name" {
  value = aws_cloudwatch_log_group.api.name
}
