# Función `birthday`

Devuelve en JSON cuánto falta (días, horas, minutos y segundos) para el próximo **5 de enero**, en hora UTC.

← [Volver al README del proyecto](../../README.md)

## Resumen

| Dato | Valor |
|---|---|
| Código | [`index.js`](index.js) (`exports.handler`) |
| Ruta del API | `GET /birthday` (en el API compartido `lambda-tests-dev-api`) |
| Nombre en AWS (dev) | `lambda-tests-dev-birthday` |
| Rol IAM | `lambda-tests-dev-birthday-role` (solo escritura de logs) |
| Log group | `/aws/lambda/lambda-tests-dev-birthday` (14 días) |
| Runtime | `nodejs22.x`, 128 MB, timeout 10 s (valores por defecto) |
| Dependencias npm | Ninguna |
| Variables de entorno | Ninguna |

## Configuración en Terraform

Entrada en [`terraform/environments/dev/terraform.tfvars`](../../terraform/environments/dev/terraform.tfvars). Con ella, Terraform crea la función y la publica en el API Gateway (integración, ruta y permiso), igual que `countdown`:

```hcl
lambdas = {
  # ...
  birthday = {
    route_key = "GET /birthday"
  }
}
```

## Petición y respuesta

No recibe parámetros: ignora el evento.

```bash
curl -s https://<api-id>.execute-api.eu-west-1.amazonaws.com/birthday
```

```json
{
  "target_date": "2027-01-05",
  "is_today": false,
  "time_remaining": { "days": 59, "hours": 10, "minutes": 3, "seconds": 41 },
  "message": "Faltan 59 días, 10 horas, 3 minutos y 41 segundos para el 5 de enero 🎂"
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `target_date` | texto | Fecha objetivo (`AAAA-01-05`) |
| `is_today` | booleano | `true` si hoy (en UTC) es 5 de enero |
| `time_remaining` | objeto | `days`, `hours`, `minutes`, `seconds` que faltan |
| `message` | texto | El mismo dato en una frase. También se escribe en los logs. |

Siempre responde `200` con `Content-Type: application/json`.

## Probar

Todos los comandos se ejecutan en la consola Ubuntu de WSL.

```bash
# En local, sin AWS (requiere: sudo apt-get install -y nodejs)
cd ~/Lambda-Tests
node -e 'require("./lambdas/birthday/index.js").handler({}).then(r => console.log(JSON.stringify(r, null, 2)))'

# Desplegada, a través del API
cd ~/Lambda-Tests/terraform/environments/dev
curl -s "$(terraform output -raw api_endpoint)/birthday"; echo

# Desplegada, invocando la Lambda directamente (sin pasar por el API)
aws lambda invoke --region eu-west-1 --function-name lambda-tests-dev-birthday /tmp/birthday.json && cat /tmp/birthday.json; echo

# Logs
aws logs tail /aws/lambda/lambda-tests-dev-birthday --region eu-west-1 --since 10m --follow
```

## Notas

- La cuenta atrás es hacia las **00:00 UTC** del 5 de enero, no la hora local del cliente.
- Todo el cálculo usa UTC (`getUTCFullYear`, `Date.UTC`), así que da el mismo resultado en AWS y en tu Ubuntu, aunque esté en otra zona horaria.
- **El propio 5 de enero:** `is_today` vale `true`, el mensaje felicita y la cuenta ya apunta al 5 de enero del año siguiente.

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `{"message":"Not Found"}` | Usa `GET` y la ruta `/birthday` exacta. Comprueba `terraform output api_urls`. |
| `{"message":"Internal Server Error"}` | Revisa los logs de la función y `integrationErr` en `/aws/apigateway/lambda-tests-dev-api`. |
| El cambio en `index.js` no aparece | Ejecuta `terraform apply` en `terraform/environments/dev`. |
