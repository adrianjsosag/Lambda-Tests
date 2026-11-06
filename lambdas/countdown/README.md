# Función `countdown`

Devuelve en JSON cuánto falta (días, horas, minutos y segundos) para el próximo Año Nuevo, en hora UTC.

← [Volver al README del proyecto](../../README.md)

## Resumen

| Dato | Valor |
|---|---|
| Código | [`index.js`](index.js) (`exports.handler`) |
| Ruta del API | `GET /countdown` |
| Nombre en AWS (dev) | `lambda-tests-dev-countdown` |
| Rol IAM | `lambda-tests-dev-countdown-role` (solo escritura de logs) |
| Log group | `/aws/lambda/lambda-tests-dev-countdown` (14 días) |
| Runtime | `nodejs22.x`, 128 MB, timeout 10 s (valores por defecto) |
| Dependencias npm | Ninguna |
| Variables de entorno | Ninguna |

## Configuración en Terraform

Entrada en [`terraform/environments/dev/terraform.tfvars`](../../terraform/environments/dev/terraform.tfvars):

```hcl
lambdas = {
  countdown = {
    route_key = "GET /countdown"
  }
}
```

## Petición y respuesta

No recibe parámetros: ignora el evento.

```bash
curl -s https://<api-id>.execute-api.eu-west-1.amazonaws.com/countdown
```

```json
{
  "target_year": 2027,
  "time_remaining": { "days": 55, "hours": 10, "minutes": 3, "seconds": 41 },
  "message": "Faltan 55 días, 10 horas, 3 minutos y 41 segundos para Año Nuevo 🎉"
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `target_year` | número | Año cuyo 1 de enero se está contando |
| `time_remaining` | objeto | `days`, `hours`, `minutes`, `seconds` que faltan |
| `message` | texto | El mismo dato en una frase. También se escribe en los logs. |

Siempre responde `200` con `Content-Type: application/json`.

## Probar

Todos los comandos se ejecutan en la consola Ubuntu de WSL.

```bash
# En local, sin AWS (requiere: sudo apt-get install -y nodejs)
cd ~/Lambda-Tests
node -e 'require("./lambdas/countdown/index.js").handler({}).then(r => console.log(JSON.stringify(r, null, 2)))'

# Desplegada, a través del API
cd ~/Lambda-Tests/terraform/environments/dev
curl -s "$(terraform output -raw api_endpoint)/countdown"; echo

# Desplegada, invocando la Lambda directamente (sin pasar por el API)
aws lambda invoke --region eu-west-1 --function-name lambda-tests-dev-countdown /tmp/countdown.json && cat /tmp/countdown.json; echo

# Logs
aws logs tail /aws/lambda/lambda-tests-dev-countdown --region eu-west-1 --since 10m --follow
```

## Notas

- La cuenta atrás es hacia las **00:00 UTC** del 1 de enero, no la hora local del cliente.
- Todo el cálculo usa UTC (`getUTCFullYear`, `Date.UTC`), así que da el mismo resultado en AWS (que corre en UTC) y en tu Ubuntu, aunque esté en otra zona horaria (por ejemplo `America/Bogota`).
- El 1 de enero ya cuenta hacia el año siguiente (`target_year` = año actual + 1 siempre).

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `{"message":"Not Found"}` | Usa `GET` y la ruta `/countdown` exacta. |
| `{"message":"Internal Server Error"}` | Revisa los logs de la función y `integrationErr` en `/aws/apigateway/lambda-tests-dev-api`. |
| El cambio en `index.js` no aparece | Ejecuta `terraform apply` en `terraform/environments/dev`. |
