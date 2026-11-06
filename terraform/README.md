# Infraestructura Terraform: funciones Lambda + API Gateway

Despliega cada función de [`lambdas/<nombre>/`](../lambdas) en AWS Lambda y la publica por HTTPS en su propia ruta de **un único API Gateway HTTP API** compartido. Qué funciones se despliegan, y con qué ruta y configuración, se declara en el mapa `lambdas` de [`environments/dev/terraform.tfvars`](environments/dev/terraform.tfvars):

```hcl
lambdas = {
  countdown = {
    route_key = "GET /countdown"
  }

  birthday = {
    route_key = "GET /birthday"
  }
}
```

| Función | Ruta | Descripción |
|---|---|---|
| [`countdown`](../lambdas/countdown/README.md) | `GET /countdown` | Tiempo que falta para Año Nuevo |
| [`birthday`](../lambdas/birthday/README.md) | `GET /birthday` | Tiempo que falta para el próximo 5 de enero |

Para añadir funciones, sigue la guía [Cómo añadir una nueva función Lambda](../README.md#cómo-añadir-una-nueva-función-lambda) del README raíz.

> **Entorno de trabajo:** todos los comandos de este documento se ejecutan en la **consola Linux Ubuntu de WSL**, dentro de `~/Lambda-Tests`. No uses PowerShell ni CMD, ni abras el proyecto por la ruta `\\wsl.localhost\...` para ejecutar Terraform (ver [Problemas frecuentes](#problemas-frecuentes)).

## Contenido

1. [Arquitectura](#arquitectura)
2. [Estructura de directorios](#estructura-de-directorios)
3. [Convenciones comunes](#convenciones-comunes)
4. [Dependencias y orden de despliegue](#dependencias-y-orden-de-despliegue)
5. [Probar sin desplegar nada](#probar-sin-desplegar-nada)
6. [Guía de despliegue paso a paso](#guía-de-despliegue-paso-a-paso)
7. [Cómo destruir todo](#cómo-destruir-todo)
8. [Costes en AWS](#costes-en-aws)
9. [Seguridad](#seguridad)
10. [Pendientes conocidos](#pendientes-conocidos)
11. [Problemas frecuentes](#problemas-frecuentes)
12. [Documentación de los módulos](#documentación-de-los-módulos)

## Arquitectura

```mermaid
flowchart LR
    client(["Cliente<br/>curl / navegador"])

    subgraph aws["Cuenta AWS (eu-west-1)"]
        subgraph apigw["API Gateway HTTP API (compartido)<br/>lambda-tests-dev-api"]
            stage["Stage $default<br/>auto_deploy + throttling"]
            route1["Ruta<br/>GET /countdown"]
            route2["Ruta<br/>GET /birthday"]
            routeN["Ruta<br/>GET /&lt;nombre&gt;"]
        end

        subgraph f1["Por función: countdown"]
            lambda1["Lambda<br/>lambda-tests-dev-countdown"]
            role1["Rol IAM<br/>...-countdown-role"]
            lg1["/aws/lambda/lambda-tests-dev-countdown"]
        end

        subgraph f2["Por función: birthday"]
            lambda2["Lambda<br/>lambda-tests-dev-birthday"]
            role2["Rol IAM<br/>...-birthday-role"]
            lg2["/aws/lambda/lambda-tests-dev-birthday"]
        end

        subgraph fN["Por función: &lt;nombre&gt; (futuras)"]
            lambdaN["Lambda<br/>lambda-tests-dev-&lt;nombre&gt;"]
            roleN["Rol IAM<br/>...-&lt;nombre&gt;-role"]
            lgN["/aws/lambda/lambda-tests-dev-&lt;nombre&gt;"]
        end

        lg_api["/aws/apigateway/lambda-tests-dev-api"]
        s3[("S3<br/>lambda-tests-tfstate-ACCOUNT_ID<br/>estado de Terraform")]
    end

    client -- HTTPS --> stage
    stage --> route1 -- "AWS_PROXY<br/>payload 2.0" --> lambda1
    stage --> route2 -- "AWS_PROXY<br/>payload 2.0" --> lambda2
    stage --> routeN -- "AWS_PROXY<br/>payload 2.0" --> lambdaN
    lambda1 -. asume .-> role1
    lambda2 -. asume .-> role2
    lambdaN -. asume .-> roleN
    lambda1 -- console.log --> lg1
    lambda2 -- console.log --> lg2
    lambdaN -- console.log --> lgN
    stage -- access logs --> lg_api
```

- **Compartido por todas las funciones:** el HTTP API, su stage `$default` y el log group de access logs.
- **Por cada función** (7 recursos): rol IAM + attachment, log group, función Lambda, integración, ruta y permiso de invocación.

- **Sin VPC.** La función no accede a recursos privados, así que corre en la red gestionada por AWS. No hacen falta subredes ni NAT, y por tanto no hay coste fijo.
- **HTTP API (v2)** en lugar de REST API (v1): es más barata, necesita menos recursos y basta para una integración proxy con Lambda.
- El bucket S3 solo guarda el **estado de Terraform**. La aplicación no lo usa.

## Estructura de directorios

```
Lambda-Tests/
├── README.md                    # visión general + guía para añadir funciones
├── lambdas/                     # una carpeta por función (nombre = clave en tfvars)
│   ├── birthday/
│   │   ├── index.js             # código de la función
│   │   └── README.md            # documentación de la función
│   └── countdown/
│       ├── index.js
│       └── README.md
└── terraform/
    ├── README.md                # este documento
    ├── bootstrap/               # stack independiente (estado local): crea el bucket de estado
    │   ├── README.md
    │   ├── main.tf              # recursos S3 definidos directamente (sin módulo)
    │   ├── outputs.tf           # state_bucket_name, state_bucket_arn
    │   ├── variables.tf         # region, project, force_destroy
    │   └── versions.tf          # incluye el provider aws
    ├── environments/
    │   └── dev/                 # stack del entorno dev (estado en S3)
    │       ├── backend.tf       # backend "s3" con use_lockfile
    │       ├── main.tf          # compone los módulos (for_each sobre var.lambdas)
    │       ├── outputs.tf       # api_endpoint, api_urls, lambda_function_names, ...
    │       ├── providers.tf     # provider aws + default_tags
    │       ├── terraform.tfvars # region, project, environment y mapa lambdas
    │       ├── variables.tf     # incluye el tipo y las validaciones de lambdas
    │       └── versions.tf
    └── modules/
        ├── iam/                 # rol de ejecución (uno por función)
        ├── cloudwatch/          # log groups de las Lambdas (uno por función) y del API
        ├── lambda/              # empaquetado zip + función (uno por función)
        └── api-gateway/         # HTTP API y stage compartidos + integración, ruta y permiso por función
```

## Convenciones comunes

| Tema | Convención |
|---|---|
| Funciones | Clave del mapa `lambdas` = carpeta `lambdas/<clave>/` = sufijo del nombre. Solo minúsculas, números y guiones (hay validación). Cada `route_key` debe ser único. |
| Nombres de recursos | `<project>-<environment>-<componente>`. Ejemplos: `lambda-tests-dev-countdown`, `lambda-tests-dev-countdown-role`, `lambda-tests-dev-api`. Se calculan en `locals` de [`environments/dev/main.tf`](environments/dev/main.tf). |
| Direcciones en el estado | Los recursos por función llevan la clave: `module.lambda["countdown"]`, `module.iam["countdown"]`, `module.api_gateway.aws_apigatewayv2_route.this["countdown"]`… En la shell, ponlas entre comillas simples. |
| Bucket de estado | `<project>-tfstate-<account_id>`. El ID de cuenta garantiza que el nombre sea único en todo S3. |
| Log groups | `/aws/lambda/<función>` y `/aws/apigateway/<api>`. |
| Estructura de módulo | `main.tf` (recursos), `variables.tf` (entradas), `outputs.tf` (salidas) y `README.md`. |
| Módulos y stacks | Los entornos (`environments/<env>`) componen módulos de `modules/`. La excepción es `bootstrap/`, que define sus 4 recursos S3 directamente porque tienen un único uso. |
| Providers | Los módulos **no** declaran bloque `provider`: lo heredan del stack que los llama (`environments/<env>` o `bootstrap`). |
| Etiquetas | Se aplican con `default_tags` del provider: `Project`, `Environment` (solo en entornos) y `ManagedBy = terraform`. Los módulos no repiten tags. |
| Versiones | Terraform `>= 1.10` (necesario para `use_lockfile`), provider `hashicorp/aws ~> 6.0` y `hashicorp/archive ~> 2.7`. Los `.terraform.lock.hcl` se suben a git. |
| Estado | Una clave por entorno, `<env>/terraform.tfstate`, en el bucket de bootstrap. El bloqueo usa un archivo `.tflock` en S3, sin DynamoDB. |
| Idioma | Las descripciones de variables y los comentarios están en español. |
| Formato | `terraform fmt -recursive` antes de cada commit. |

## Dependencias y orden de despliegue

```mermaid
flowchart TD
    boot["1. terraform/bootstrap<br/>bucket S3 de estado"]
    backend["backend.tf de dev<br/>(bucket de estado)"]

    subgraph dev["2. terraform/environments/dev"]
        tfvars[/"terraform.tfvars<br/>mapa lambdas"/]
        iam["módulo iam[clave]<br/>(for_each)"]
        cw["módulo cloudwatch"]
        lambda["módulo lambda[clave]<br/>(for_each)"]
        api["módulo api-gateway"]
    end

    boot -- state_bucket_name --> backend
    backend --> dev
    tfvars --> iam & cw & lambda & api
    iam -- role_arn --> lambda
    cw -- "lambda_log_group_names[clave]" --> lambda
    cw -- api_log_group_arn --> api
    lambda -- "invoke_arn<br/>function_name" --> api
```

**Orden:**

1. `terraform/bootstrap`: se aplica **una sola vez** por cuenta y crea el bucket de estado.
2. `terraform/environments/dev`: un solo `apply`. Terraform calcula el orden interno a partir de las referencias:
   1. `iam` (cada rol) y `cloudwatch`, en paralelo.
   2. `lambda` (cada función), que necesita su rol y su log group.
   3. `api-gateway`, que necesita el `invoke_arn` y el nombre de cada función.

| Output (módulo origen) | Input (módulo destino) |
|---|---|
| `iam[clave].role_arn` | `lambda[clave].role_arn` |
| `cloudwatch.lambda_log_group_names[clave]` | `lambda[clave].log_group_name` |
| `cloudwatch.api_log_group_arn` | `api_gateway.log_group_arn` |
| `lambda[clave].invoke_arn` | `api_gateway.routes[clave].lambda_invoke_arn` |
| `lambda[clave].function_name` | `api_gateway.routes[clave].lambda_function_name` |
| `var.lambdas[clave].route_key` | `api_gateway.routes[clave].route_key` |
| `bootstrap.state_bucket_name` | `bucket` en `environments/dev/backend.tf` (se copia a mano) |

La dependencia `lambda → log group` es **implícita**: el módulo lambda usa el nombre del log group en `logging_config`, así que Terraform crea el log group primero. Si no fuese así, Lambda crearía el log group por su cuenta al primer `console.log`, sin retención, y el siguiente `apply` fallaría con un conflicto.

## Probar sin desplegar nada

Ninguno de estos pasos crea recursos en AWS.

```bash
cd ~/Lambda-Tests/terraform

# 1. Formato (no modifica nada con -check)
terraform fmt -recursive -check -diff

# 2. Sintaxis y tipos, sin backend ni credenciales
(cd bootstrap        && terraform init -backend=false -input=false && terraform validate)
(cd environments/dev && terraform init -backend=false -input=false && terraform validate)
```

**Ejecutar una función en local** (requiere Node.js, ver [requisitos](#1-requisitos-en-ubuntu-wsl)):

```bash
cd ~/Lambda-Tests
node -e 'require("./lambdas/countdown/index.js").handler({}).then(r => console.log(JSON.stringify(r, null, 2)))'
node -e 'require("./lambdas/birthday/index.js").handler({}).then(r => console.log(JSON.stringify(r, null, 2)))'
```

**Ver el plan** (solo lectura, pero necesita credenciales AWS y, en `dev`, que el bucket de estado ya exista):

```bash
cd ~/Lambda-Tests/terraform/bootstrap && terraform init && terraform plan
cd ~/Lambda-Tests/terraform/environments/dev && terraform init && terraform plan
```

**Ver el plan de dev sin haber creado aún el bucket de estado.** Un archivo `*_override.tf` (ignorado por git) cambia el backend a local solo para esta prueba. **No ejecutes `apply` así**, o el estado quedaría en local:

```bash
cd ~/Lambda-Tests/terraform/environments/dev
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
terraform init -reconfigure && terraform plan
# Esperado con countdown y birthday: "Plan: 17 to add, 0 to change, 0 to destroy."
# (3 compartidos: API, stage y log group del API + 7 por función)
rm -rf backend_override.tf .terraform terraform.tfstate* build   # deshacer la prueba
```

**Análisis estático opcional** (no viene instalado):

```bash
tflint --recursive                    # buenas prácticas y errores del provider
checkov -d ~/Lambda-Tests/terraform   # reglas de seguridad
trivy config ~/Lambda-Tests/terraform # alternativa a checkov
```

## Guía de despliegue paso a paso

### 1. Requisitos en Ubuntu (WSL)

```bash
# Herramientas base
sudo apt-get update && sudo apt-get install -y curl unzip gnupg lsb-release

# Terraform (repositorio oficial de HashiCorp)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform

# AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install --update

# Node.js (opcional, solo para probar la función en local)
sudo apt-get install -y nodejs

terraform version   # >= 1.10
aws --version       # aws-cli/2.x
```

### 2. Credenciales AWS (dentro de Ubuntu)

Las credenciales se guardan en `~/.aws` **de Ubuntu**. Las que tengas configuradas en Windows no se ven desde WSL.

```bash
aws configure          # claves de acceso de un usuario IAM
# o bien
aws configure sso      # IAM Identity Center (recomendado)
export AWS_PROFILE=<perfil>   # si no usas el perfil "default"

aws sts get-caller-identity   # comprueba la cuenta y la identidad ANTES de desplegar
```

La identidad necesita permisos sobre **S3, IAM (roles), Lambda, API Gateway y CloudWatch Logs**.

### 3. Crear el bucket de estado (una sola vez)

```bash
cd ~/Lambda-Tests/terraform/bootstrap
terraform init
terraform plan
terraform apply
terraform output -raw state_bucket_name   # p. ej. lambda-tests-tfstate-123456789012
```

El estado de este stack queda en `bootstrap/terraform.tfstate`, en local. Guárdalo bien: está en `.gitignore` y no se sube a git.

### 4. Configurar el backend de dev

Sustituye el placeholder de [`environments/dev/backend.tf`](environments/dev/backend.tf) por el nombre que devolvió el paso anterior:

```bash
cd ~/Lambda-Tests/terraform
BUCKET=$(terraform -chdir=bootstrap output -raw state_bucket_name)
sed -i "s/lambda-tests-tfstate-<ACCOUNT_ID>/${BUCKET}/" environments/dev/backend.tf
grep bucket environments/dev/backend.tf
```

Si has cambiado la región, ajústala en `bootstrap/variables.tf`, `environments/dev/terraform.tfvars` **y** `environments/dev/backend.tf`.

### 5. Desplegar dev

```bash
cd ~/Lambda-Tests/terraform/environments/dev
terraform init -reconfigure
terraform plan -out=tfplan
terraform apply tfplan
```

### 6. Verificar

```bash
terraform output api_urls
# api_urls = {
#   "birthday"  = "https://<id>.execute-api.eu-west-1.amazonaws.com/birthday"
#   "countdown" = "https://<id>.execute-api.eu-west-1.amazonaws.com/countdown"
# }

curl -s "$(terraform output -raw api_endpoint)/countdown"; echo
# {"target_year":2027,"time_remaining":{...},"message":"Faltan ... para Año Nuevo 🎉"}

curl -s "$(terraform output -raw api_endpoint)/birthday"; echo
# {"target_date":"2027-01-05","is_today":false,"time_remaining":{...},"message":"Faltan ... para el 5 de enero 🎂"}

aws logs tail /aws/lambda/lambda-tests-dev-countdown --since 10m
aws logs tail /aws/lambda/lambda-tests-dev-birthday --since 10m
aws logs tail "$(terraform output -raw api_log_group)" --since 10m

terraform plan   # debe decir "No changes"
```

| Output | Contenido |
|---|---|
| `api_endpoint` | URL base del API compartido |
| `api_urls` | Mapa función => URL completa |
| `lambda_function_names` | Mapa función => nombre en AWS |
| `lambda_log_groups` | Mapa función => log group |
| `api_log_group` | Log group de los access logs |

### 7. Actualizar el código

Edita `lambdas/<nombre>/index.js` y vuelve a ejecutar `terraform apply` en `environments/dev`. El zip de esa función se regenera y, al cambiar su `source_code_hash`, Terraform sube solo la nueva versión de esa función. No hace falta ningún paso manual.

### 8. Añadir, cambiar o quitar funciones

- **Añadir:** crea `lambdas/<nombre>/` y añade la entrada al mapa `lambdas` de `terraform.tfvars`. Guía completa con la función de ejemplo `lambda-example`: [Cómo añadir una nueva función Lambda](../README.md#cómo-añadir-una-nueva-función-lambda).
- **Cambiar ruta, memoria, timeout o variables de entorno:** edita su entrada en `terraform.tfvars` y `apply`.
- **Quitar:** borra su entrada del mapa y ejecuta `apply` (destruye sus 7 recursos, incluidos sus logs). Después ya puedes borrar la carpeta.

## Cómo destruir todo

El orden es el inverso al del despliegue: primero el entorno y después el bucket de estado.

```bash
# 1. Entorno dev: Lambda, API, rol y logs
cd ~/Lambda-Tests/terraform/environments/dev
terraform destroy

# 2. Bucket de estado. Está versionado y force_destroy = false, así que
#    Terraform no lo borra mientras tenga objetos o versiones antiguas.
#    Activa force_destroy solo para esta operación:
cd ~/Lambda-Tests/terraform/bootstrap
terraform apply   -var force_destroy=true   # solo cambia el atributo force_destroy
terraform destroy -var force_destroy=true   # borra el bucket con todas sus versiones

# 3. Limpieza local
cd ~/Lambda-Tests/terraform
rm -rf bootstrap/.terraform bootstrap/terraform.tfstate* \
       environments/dev/.terraform environments/dev/build environments/dev/tfplan
```

> ⚠️ Destruir el bucket elimina el estado de **todos** los entornos que lo usen. Hazlo solo después de destruir esos entornos.

## Costes en AWS

Precios de referencia en **eu-west-1**, en USD. Pueden cambiar: compruébalos en la [calculadora de AWS](https://calculator.aws/).

| Servicio | Tarifa | Capa gratuita | Notas |
|---|---|---|---|
| Lambda: peticiones | $0,20 por millón | 1 M/mes (permanente) | |
| Lambda: cómputo | $0,0000166667 por GB-s | 400 000 GB-s/mes (permanente) | 128 MB × ~10 ms por llamada |
| API Gateway HTTP API | $1,00 por millón (primeros 300 M) | 1 M/mes los primeros 12 meses | |
| CloudWatch Logs: ingesta | ~$0,57 por GB | 5 GB/mes | ~0,7 KB por llamada (logs de Lambda + access log) |
| CloudWatch Logs: almacenamiento | $0,03 por GB-mes | 5 GB | Retención de 14 días |
| S3 (estado) | ~$0,023 por GB-mes + peticiones | 5 GB los primeros 12 meses | Unos KB, céntimos al mes |
| IAM | Gratis | | |

**Estimación mensual:**

| Tráfico | Lambda | API Gateway | Logs | Total aprox. |
|---|---|---|---|---|
| 100 000 peticiones | $0 | $0 – $0,10 | $0 | **< $0,15** |
| 10 M peticiones | ~$1,80 | ~$10 | ~$1,50 – $4 | **~$14 – $16** |

No hay costes fijos: sin VPC, sin NAT Gateway y sin instancias. Si no hay tráfico, el coste es prácticamente $0. Para no llevarte sorpresas, crea un **AWS Budget** con alerta (por ejemplo, de $5/mes).

## Seguridad

**Lo que ya está implementado:**

- **Mínimo privilegio:** el rol de la Lambda solo tiene `AWSLambdaBasicExecutionRole`, es decir, permiso para escribir sus logs.
- **Un rol por función:** los permisos extra que necesite una función no los hereda ninguna otra.
- **Permiso de invocación acotado:** `aws_lambda_permission` solo deja invocar cada función al API de este stack (`source_arn = <execution_arn>/*/*`).
- **Bucket de estado:** cifrado SSE-S3, versionado (permite recuperar estados anteriores) y bloqueo total de acceso público.
- **Throttling** en el stage (100 peticiones/s y ráfaga de 50), que limita abusos y el coste.
- **Access logs** del API en CloudWatch, para auditar las peticiones.

**Riesgos y recomendaciones:**

- **El API es público y no tiene autenticación.** Cualquiera con la URL puede invocarlo. Opciones:
  - JWT authorizer con Cognito u otro IdP OIDC (`aws_apigatewayv2_authorizer`).
  - Autorización IAM (`authorization_type = "AWS_IAM"` en la ruta) con firma SigV4.
  - Lambda authorizer, para lógica propia (API keys, cabeceras).
  - Los HTTP API no admiten WAF directamente. Si lo necesitas, pon CloudFront con WAF delante.
- **El estado de Terraform puede contener datos sensibles.** No lo subas a git (`.gitignore` ya lo excluye) y restringe quién puede leer el bucket.
- Usa **credenciales temporales** (SSO o roles), no claves de acceso de larga duración.
- No guardes secretos en `environment_variables` de la Lambda. Usa Secrets Manager o SSM Parameter Store.

## Pendientes conocidos

- `environments/dev/backend.tf` tiene un **placeholder** (`<ACCOUNT_ID>`) que hay que sustituir a mano tras el bootstrap.
- La **región está repetida** en tres sitios (`bootstrap/variables.tf`, `dev/terraform.tfvars`, `dev/backend.tf`). Los backends no admiten variables. Se podría usar `-backend-config=backend.hcl`.
- El estado de **bootstrap es local**. Si se pierde, habría que importar el bucket (`terraform import aws_s3_bucket.state <bucket>`, ver [bootstrap/README.md](bootstrap/README.md#problemas-frecuentes)).
- El API no tiene **autenticación** (ver [Seguridad](#seguridad)).
- No hay **CI/CD**. Lo siguiente sería GitHub Actions con OIDC (`aws_iam_openid_connect_provider`) en lugar de claves.
- Solo existe el entorno **dev**. Para `prod` basta copiar `environments/dev` y cambiar `environment` y `key`.
- No hay **dominio propio** (ACM + Route 53 + `aws_apigatewayv2_domain_name`).
- No hay **alarmas** (errores, throttles, latencia) ni trazas **X-Ray**.
- No hay **tests automatizados** de las funciones ni de la infraestructura (`terraform test`).
- El **throttling** es común a todas las rutas del API. Si una función necesita límites propios, usa `route_settings` en el stage.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `terraform init` en dev falla con `NoSuchBucket` o un nombre de bucket inválido | `backend.tf` aún tiene `<ACCOUNT_ID>`, o no se ha aplicado bootstrap | Sigue los pasos [3](#3-crear-el-bucket-de-estado-una-sola-vez) y [4](#4-configurar-el-backend-de-dev). Después, `terraform init -reconfigure`. |
| `BucketAlreadyExists` en bootstrap | Ese nombre ya existe en otra cuenta | Cambia `project` en `bootstrap/variables.tf`. |
| `ResourceAlreadyExistsException` al crear un log group | La Lambda se ejecutó antes de que Terraform creara su log group (despliegue manual previo o `destroy` interrumpido) | `terraform import 'module.cloudwatch.aws_cloudwatch_log_group.lambda["countdown"]' /aws/lambda/lambda-tests-dev-countdown`, o bórralo con `aws logs delete-log-group`. |
| `could not archive missing directory` | Hay una clave en `lambdas` sin carpeta `lambdas/<clave>/` | Crea la carpeta o corrige la clave en `terraform.tfvars`. |
| `Cada función debe tener un route_key distinto` / `Las claves de 'lambdas' solo pueden tener...` | Validaciones de la variable `lambdas` | Corrige la entrada en `terraform.tfvars`. |
| `{"message":"Not Found"}` | Ruta o método incorrectos | Comprueba `terraform output api_urls` y el método del `route_key`. |
| `{"message":"Internal Server Error"}` | La función lanzó un error o falta el permiso de invocación | Revisa `aws logs tail /aws/lambda/lambda-tests-dev-<nombre>` y los access logs (`integrationErr`). Si es el permiso, `terraform apply`. |
| `ExpiredToken`, `AccessDenied` o `no valid credential sources` | La sesión SSO caducó, el perfil es incorrecto o faltan permisos | `aws sso login --profile <perfil>`, revisa `AWS_PROFILE` y `aws sts get-caller-identity`. |
| `SignatureDoesNotMatch` o `RequestTimeTooSkewed` | El reloj de WSL se ha desfasado (pasa al suspender el equipo) | `sudo hwclock -s` o `wsl --shutdown` y vuelve a abrir Ubuntu. |
| `Error acquiring the state lock` | Una ejecución anterior se interrumpió y dejó el `.tflock` | Comprueba que nadie más está aplicando y ejecuta `terraform force-unlock <LOCK_ID>`. |
| Terraform muy lento, errores de permisos o `\r` en scripts | Se ejecuta desde PowerShell/CMD o sobre la ruta `\\wsl.localhost\...` | Trabaja siempre en la consola Ubuntu, en `~/Lambda-Tests`. |
| Las credenciales de Windows no funcionan | WSL no lee `C:\Users\<usuario>\.aws` | Configúralas en Ubuntu con `aws configure` (o enlaza `~/.aws` a la carpeta de Windows, bajo tu responsabilidad). |
| `BucketNotEmpty` al destruir bootstrap | Bucket versionado con `force_destroy = false` | Usa `-var force_destroy=true` (ver [Cómo destruir todo](#cómo-destruir-todo)). |
| Al cambiar el código no se actualiza la función | Has editado otro directorio o no se ha aplicado | El zip sale de `~/Lambda-Tests/lambdas/<nombre>/`. Ejecuta `terraform apply` en `environments/dev`. |

## Documentación de los módulos

El stack que crea el bucket de estado está documentado en [bootstrap/README.md](bootstrap/README.md).

| Módulo | Descripción |
|---|---|
| [iam](modules/iam/README.md) | Rol de ejecución (uno por función) |
| [cloudwatch](modules/cloudwatch/README.md) | Log groups de las Lambdas y del API |
| [lambda](modules/lambda/README.md) | Empaquetado y función Lambda (uno por función) |
| [api-gateway](modules/api-gateway/README.md) | HTTP API y stage compartidos; integración, ruta y permiso por función |

Cada función tiene además su propio README en `lambdas/<nombre>/README.md` : [countdown](../lambdas/countdown/README.md) y [birthday](../lambdas/birthday/README.md).
