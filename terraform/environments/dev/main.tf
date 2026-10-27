locals {
  name          = "${var.project}-${var.environment}"
  function_name = "${local.name}-countdown"
  api_name      = "${local.name}-api"
}

module "iam" {
  source = "../../modules/iam"

  role_name = "${local.function_name}-role"
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  function_name     = local.function_name
  api_name          = local.api_name
  retention_in_days = var.log_retention_in_days
}

module "lambda" {
  source = "../../modules/lambda"

  function_name  = local.function_name
  source_dir     = "${path.root}/../../../lambda"
  role_arn       = module.iam.role_arn
  log_group_name = module.cloudwatch.lambda_log_group_name
}

module "api_gateway" {
  source = "../../modules/api-gateway"

  api_name             = local.api_name
  route_key            = "GET /countdown"
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
  log_group_arn        = module.cloudwatch.api_log_group_arn
}
