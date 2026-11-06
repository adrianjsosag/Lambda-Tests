# Módulo `lambda`

Empaqueta un directorio de código en un zip y crea **una función Lambda**. El entorno lo instancia con `for_each`, una vez por cada entrada del mapa `lambdas` de `terraform.tfvars`, empaquetando `lambdas/<clave>/`. Los logs van al log group creado por el módulo [`cloudwatch`](../cloudwatch/README.md).

← [Volver a la documentación general](../../README.md)

## Estructura de directorios

```
terraform/modules/lambda/
├── main.tf        # data.archive_file.this (zip del código), aws_lambda_function.this
├── variables.tf   # function_name, source_dir, role_arn, log_group_name, runtime,
│                  # handler, memory_size, timeout, environment_variables
├── outputs.tf     # function_name, arn, invoke_arn
└── README.md      # este documento
```

Lo llama `module "lambda"` (con `for_each = var.lambdas`) en [`environments/dev/main.tf`](../../environments/dev/main.tf).

El módulo no guarda archivos generados. El código sale de `lambdas/<clave>/` y el zip se escribe en el stack que lo llama:

```
Lambda-Tests/
├── lambdas/<clave>/                       # source_dir: lo que se empaqueta
└── terraform/environments/dev/build/
    └── lambda-tests-dev-<clave>.zip       # generado en cada plan/apply (ignorado por git)
```

## Diagrama

```mermaid
flowchart LR
    src[/"source_dir<br/>~/Lambda-Tests/lambdas/&lt;clave&gt;/"/]
    zip["data.archive_file.this<br/>&lt;path.root&gt;/build/&lt;function_name&gt;.zip"]
    fn["aws_lambda_function.this<br/>runtime nodejs22.x<br/>handler index.handler<br/>128 MB · 10 s"]

    role["módulo iam<br/>role_arn"]
    lg["módulo cloudwatch<br/>lambda_log_group_names[clave]"]

    src --> zip
    zip -- "filename<br/>source_code_hash" --> fn
    role --> fn
    lg -- logging_config --> fn
    fn -- "invoke_arn<br/>function_name" --> api["módulo api-gateway"]
```

## Recursos

| Recurso | Propósito |
|---|---|
| `data.archive_file.this` | Genera el zip del código en cada `plan`/`apply` |
| `aws_lambda_function.this` | La función |

## Inputs

| Nombre | Tipo | Default | Descripción |
|---|---|---|---|
| `function_name` | `string` | — (obligatorio) | Nombre de la función Lambda |
| `source_dir` | `string` | — (obligatorio) | Directorio con el código fuente a empaquetar |
| `role_arn` | `string` | — (obligatorio) | ARN del rol de ejecución |
| `log_group_name` | `string` | — (obligatorio) | Log group de CloudWatch donde escribe la función |
| `runtime` | `string` | `"nodejs22.x"` | Runtime de Lambda |
| `handler` | `string` | `"index.handler"` | `<archivo>.<función exportada>` |
| `memory_size` | `number` | `128` | Memoria en MB (128–10240). La CPU escala con la memoria. |
| `timeout` | `number` | `10` | Tiempo máximo de ejecución, en segundos (máx. 900) |
| `environment_variables` | `map(string)` | `{}` | Variables de entorno de la función |

## Outputs

| Nombre | Descripción |
|---|---|
| `function_name` | Nombre de la función, para el permiso de invocación del API |
| `arn` | ARN de la función |
| `invoke_arn` | ARN de invocación, usado como `integration_uri` en API Gateway |

## Dependencias

- **Recibe de:** [`iam`](../iam/README.md) (`role_arn`) y [`cloudwatch`](../cloudwatch/README.md) (`lambda_log_group_names[clave]`).
- **Alimenta a:** [`api-gateway`](../api-gateway/README.md) (`invoke_arn`, `function_name`).

## Ejemplo de uso

```hcl
module "lambda" {
  source   = "../../modules/lambda"
  for_each = var.lambdas                                  # mapa de terraform.tfvars

  function_name         = local.function_names[each.key]  # lambda-tests-dev-countdown
  source_dir            = "${local.lambdas_dir}/${each.key}" # ~/Lambda-Tests/lambdas/countdown
  role_arn              = module.iam[each.key].role_arn
  log_group_name        = module.cloudwatch.lambda_log_group_names[each.key]
  runtime               = each.value.runtime
  handler               = each.value.handler
  memory_size           = each.value.memory_size
  timeout               = each.value.timeout
  environment_variables = each.value.environment_variables
}
```

Los valores por defecto de `runtime`, `handler`, `memory_size`, `timeout` y `environment_variables` se definen en el tipo de la variable `lambdas` del entorno ([`environments/dev/variables.tf`](../../environments/dev/variables.tf)) y coinciden con los de este módulo.

Probar la función en local antes de desplegar (requiere `sudo apt-get install -y nodejs`):

```bash
cd ~/Lambda-Tests
node -e 'require("./lambdas/countdown/index.js").handler({}).then(r => console.log(r))'
node -e 'require("./lambdas/birthday/index.js").handler({}).then(r => console.log(r))'
```

Invocarla directamente en AWS, sin pasar por el API:

```bash
aws lambda invoke --function-name lambda-tests-dev-countdown /tmp/out.json && cat /tmp/out.json
```

## Notas

- **Redespliegue automático:** `source_code_hash` es el hash del zip. Si cambias cualquier archivo de `source_dir`, el siguiente `apply` sube el código nuevo.
- **El zip se escribe en `<stack>/build/`** (por ejemplo, `environments/dev/build/`). Está en `.gitignore`.
- **Dependencias npm:** ahora el código no tiene ninguna. Si añades un `package.json`, ejecuta `npm ci --omit=dev` dentro de `lambdas/<clave>/` antes de `terraform apply`, para que `node_modules` entre en el zip. Si pasa de 50 MB, súbelo a S3 (`s3_bucket` y `s3_key`) o usa una Lambda Layer.
- **Formato de respuesta:** el handler devuelve `{ statusCode, headers, body }`, que es justo lo que espera la integración proxy (payload 2.0) del API Gateway.
- **`logging_config`** además crea la dependencia implícita con el log group, que se crea antes que la función.

## Seguridad

- No pongas secretos en `environment_variables`: se ven en la consola y en el estado de Terraform. Usa Secrets Manager o SSM Parameter Store y da permiso de lectura al rol.
- Mantén el runtime en una versión con soporte. AWS retira los runtimes antiguos (por ejemplo, `nodejs18.x`).
- Mejoras posibles: `reserved_concurrent_executions` para limitar la concurrencia (y el coste) y una dead-letter queue para invocaciones asíncronas.

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `Runtime.ImportModuleError: Cannot find module 'index'` | `handler` no coincide con el archivo, o el zip no tiene `index.js` en la raíz. Comprueba `source_dir`. |
| `error archiving directory: could not archive missing directory` | Hay una clave en el mapa `lambdas` sin su carpeta `lambdas/<clave>/` (o con otro nombre). Crea la carpeta o corrige la clave, y ejecuta Terraform desde `~/Lambda-Tests/terraform/environments/dev`, dentro de WSL. |
| `Task timed out after 10.00 seconds` | Aumenta `timeout`, o `memory_size` (que da más CPU). |
| `InvalidParameterValueException: The role defined for the function cannot be assumed` | Es la propagación de IAM. Repite `terraform apply`. |
| El código nuevo no se despliega | Asegúrate de que has editado `~/Lambda-Tests/lambdas/<clave>/` y de que `terraform plan` muestra un cambio en `source_code_hash`. |
