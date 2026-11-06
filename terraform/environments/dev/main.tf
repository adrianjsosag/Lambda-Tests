locals {
  name     = "${var.project}-${var.environment}"
  api_name = "${local.name}-api"

  # <project>-<environment>-<clave>, p. ej. lambda-tests-dev-countdown
  function_names = { for k, _ in var.lambdas : k => "${local.name}-${k}" }

  # Directorio raíz del código de las funciones: ~/Lambda-Tests/lambdas
  lambdas_dir = "${path.root}/../../../lambdas"
}

module "iam" {
  source   = "../../modules/iam"
  for_each = var.lambdas

  role_name = "${local.function_names[each.key]}-role"
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  function_names    = local.function_names
  api_name          = local.api_name
  retention_in_days = var.log_retention_in_days
}

module "lambda" {
  source   = "../../modules/lambda"
  for_each = var.lambdas

  function_name         = local.function_names[each.key]
  source_dir            = "${local.lambdas_dir}/${each.key}"
  role_arn              = module.iam[each.key].role_arn
  log_group_name        = module.cloudwatch.lambda_log_group_names[each.key]
  runtime               = each.value.runtime
  handler               = each.value.handler
  memory_size           = each.value.memory_size
  timeout               = each.value.timeout
  environment_variables = each.value.environment_variables
}

module "api_gateway" {
  source = "../../modules/api-gateway"

  api_name      = local.api_name
  log_group_arn = module.cloudwatch.api_log_group_arn

  routes = {
    for k, cfg in var.lambdas : k => {
      route_key            = cfg.route_key
      lambda_invoke_arn    = module.lambda[k].invoke_arn
      lambda_function_name = module.lambda[k].function_name
    }
  }
}
