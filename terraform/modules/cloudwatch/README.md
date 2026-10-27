# Módulo `cloudwatch`

Crea los **log groups** de la función Lambda y de los access logs del API Gateway, con retención controlada.

← [Volver a la documentación general](../../README.md)

## Diagrama

```mermaid
flowchart LR
    subgraph mod["módulo cloudwatch"]
        lg_lambda["aws_cloudwatch_log_group.lambda<br/>/aws/lambda/&lt;function_name&gt;<br/>retención: retention_in_days"]
        lg_api["aws_cloudwatch_log_group.api<br/>/aws/apigateway/&lt;api_name&gt;<br/>retención: retention_in_days"]
    end

    lg_lambda -- lambda_log_group_name --> lambda["módulo lambda<br/>logging_config.log_group"]
    lg_api -- api_log_group_arn --> api["módulo api-gateway<br/>access_log_settings"]

    fn(["Ejecución de la Lambda"]) -. console.log, START/END/REPORT .-> lg_lambda
    stage(["Stage $default"]) -. una línea JSON por petición .-> lg_api
```

## Recursos

| Recurso | Nombre en AWS | Propósito |
|---|---|---|
| `aws_cloudwatch_log_group.lambda` | `/aws/lambda/<function_name>` | Logs de la función |
| `aws_cloudwatch_log_group.api` | `/aws/apigateway/<api_name>` | Access logs del stage del API |

## Inputs

| Nombre | Tipo | Default | Descripción |
|---|---|---|---|
| `function_name` | `string` | — (obligatorio) | Nombre de la función Lambda (define el nombre de su log group) |
| `api_name` | `string` | — (obligatorio) | Nombre del API Gateway (define el nombre del log group de access logs) |
| `retention_in_days` | `number` | `14` | Días de retención de los logs. Valores válidos: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365… |

## Outputs

| Nombre | Descripción |
|---|---|
| `lambda_log_group_name` | Nombre del log group de la Lambda. Es la entrada `log_group_name` del módulo `lambda`. |
| `api_log_group_arn` | ARN del log group del API. Es la entrada `log_group_arn` del módulo `api-gateway`. |

## Dependencias

- **Recibe de:** nada. Solo necesita los nombres que se calculan en `locals` del entorno.
- **Alimenta a:** [`lambda`](../lambda/README.md) y [`api-gateway`](../api-gateway/README.md).

## Ejemplo de uso

```hcl
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  function_name     = local.function_name   # lambda-tests-dev-countdown
  api_name          = local.api_name        # lambda-tests-dev-api
  retention_in_days = var.log_retention_in_days
}
```

Consultar los logs desde Ubuntu:

```bash
aws logs tail /aws/lambda/lambda-tests-dev-countdown --follow
aws logs tail /aws/apigateway/lambda-tests-dev-api --since 1h
```

## Notas

- **Por qué crear el log group de la Lambda con Terraform:** si no existe, Lambda lo crea sola en la primera invocación, **sin caducidad** (los logs se acumulan y se pagan para siempre) y fuera del estado de Terraform. Por eso el módulo `lambda` lo referencia en `logging_config`, para que se cree primero.
- **Coste:** la ingesta (~$0,57/GB en eu-west-1) suele ser lo que más cuesta. Bajar `retention_in_days` reduce el almacenamiento, pero no la ingesta.
- Al hacer `terraform destroy` se borran los log groups **y sus logs**.

## Seguridad

- Los logs pueden contener datos de las peticiones. El formato de access log de este proyecto guarda la **IP de origen**, que puede ser un dato personal según la normativa aplicable.
- Mejora posible: cifrar los log groups con una clave KMS (`kms_key_id`).

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `ResourceAlreadyExistsException: The specified log group already exists` | Lambda creó el log group antes que Terraform. Ejecuta `terraform import module.cloudwatch.aws_cloudwatch_log_group.lambda /aws/lambda/lambda-tests-dev-countdown` o bórralo con `aws logs delete-log-group`. |
| No aparecen access logs | Comprueba que el stage tiene `access_log_settings` y que has hecho al menos una petición. Los logs pueden tardar unos segundos en aparecer. |
| `InvalidParameterException` en `retention_in_days` | El valor tiene que ser uno de los admitidos por CloudWatch (ver Inputs). |
