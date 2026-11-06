resource "aws_cloudwatch_log_group" "lambda" {
  for_each = var.function_names

  name              = "/aws/lambda/${each.value}"
  retention_in_days = var.retention_in_days
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.retention_in_days
}
