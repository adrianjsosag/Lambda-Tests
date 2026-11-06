# Módulo `cloudwatch`

Crea los **log groups** de todas las funciones Lambda (uno por función) y el de los access logs del API Gateway compartido, con retención controlada.

← [Volver a la documentación general](../../README.md)

## Estructura de directorios

```
terraform/modules/cloudwatch/
├── main.tf        # aws_cloudwatch_log_group.lambda (uno por función, for_each = function_names)
│                  # y aws_cloudwatch_log_group.api (access logs del API)
├── variables.tf   # function_names, api_name, retention_in_days
├── outputs.tf     # lambda_log_group_names, api_log_group_arn, api_log_group_name
└── README.md      # este documento
```

Lo llama `module "cloudwatch"` en [`environments/dev/main.tf`](../../environments/dev/main.tf).

## Diagrama

```mermaid
flowchart LR
    subgraph mod["módulo cloudwatch"]
        lg_lambda["aws_cloudwatch_log_group.lambda[clave]<br/>/aws/lambda/&lt;nombre de la función&gt;<br/>uno por función (for_each)"]
        lg_api["aws_cloudwatch_log_group.api<br/>/aws/apigateway/&lt;api_name&gt;"]
    end

    lg_lambda -- "lambda_log_group_names[clave]" --> lambda["módulo lambda[clave]<br/>logging_config.log_group"]
    lg_api -- api_log_group_arn --> api["módulo api-gateway<br/>access_log_settings"]

    fn(["Ejecución de cada Lambda"]) -. console.log, START/END/REPORT .-> lg_lambda
    stage(["Stage $default"]) -. una línea JSON por petición .-> lg_api
```

## Recursos

| Recurso | Nombre en AWS | Propósito |
|---|---|---|
| `aws_cloudwatch_log_group.lambda[clave]` | `/aws/lambda/<project>-<env>-<clave>` | Logs de cada función |
| `aws_cloudwatch_log_group.api` | `/aws/apigateway/<api_name>` | Access logs del stage del API |

## Inputs

| Nombre | Tipo | Default | Descripción |
|---|---|---|---|
| `function_names` | `map(string)` | — (obligatorio) | Mapa clave => nombre de la función. Crea un log group por entrada. |
| `api_name` | `string` | — (obligatorio) | Nombre del API Gateway (define el nombre del log group de access logs) |
| `retention_in_days` | `number` | `14` | Días de retención de los logs. Valores válidos: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365… |

## Outputs

| Nombre | Descripción |
|---|---|
| `lambda_log_group_names` | Mapa clave => log group. `lambda_log_group_names[clave]` es la entrada `log_group_name` del módulo `lambda`. |
| `api_log_group_arn` | ARN del log group del API. Es la entrada `log_group_arn` del módulo `api-gateway`. |
| `api_log_group_name` | Nombre del log group del API (para el output del entorno). |

## Dependencias

- **Recibe de:** nada. Solo necesita los nombres que se calculan en `locals` del entorno.
- **Alimenta a:** [`lambda`](../lambda/README.md) y [`api-gateway`](../api-gateway/README.md).

## Ejemplo de uso

```hcl
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  function_names    = local.function_names   # { countdown = "lambda-tests-dev-countdown", birthday = "lambda-tests-dev-birthday" }
  api_name          = local.api_name         # lambda-tests-dev-api
  retention_in_days = var.log_retention_in_days
}
```

Consultar los logs desde la consola Ubuntu de WSL:

```bash
aws logs tail /aws/lambda/lambda-tests-dev-countdown --follow
aws logs tail /aws/lambda/lambda-tests-dev-birthday --follow
aws logs tail /aws/apigateway/lambda-tests-dev-api --since 1h
```

## Notas

- **Por qué crear los log groups con Terraform:** si no existe, Lambda lo crea sola en la primera invocación, **sin caducidad** (los logs se acumulan y se pagan para siempre) y fuera del estado de Terraform. Por eso el módulo `lambda` lo referencia en `logging_config`, para que se cree primero.
- **Coste:** la ingesta (~$0,57/GB en eu-west-1) suele ser lo que más cuesta. Bajar `retention_in_days` reduce el almacenamiento, pero no la ingesta.
- Al quitar una función del mapa `lambdas`, su log group se borra **con sus logs** en el siguiente `apply`. Lo mismo con `terraform destroy`.

## Seguridad

- Los logs pueden contener datos de las peticiones. El formato de access log de este proyecto guarda la **IP de origen**, que puede ser un dato personal según la normativa aplicable.
- Mejora posible: cifrar los log groups con una clave KMS (`kms_key_id`).

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `ResourceAlreadyExistsException: The specified log group already exists` | Lambda creó el log group antes que Terraform. Impórtalo: `terraform import 'module.cloudwatch.aws_cloudwatch_log_group.lambda["countdown"]' /aws/lambda/lambda-tests-dev-countdown`, o bórralo con `aws logs delete-log-group`. |
| No aparecen access logs | Comprueba que el stage tiene `access_log_settings` y que has hecho al menos una petición. Los logs pueden tardar unos segundos en aparecer. |
| `InvalidParameterException` en `retention_in_days` | El valor tiene que ser uno de los admitidos por CloudWatch (ver Inputs). |
