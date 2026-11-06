region      = "eu-west-1"
project     = "lambda-tests"
environment = "dev"

# Funciones Lambda: la clave es la carpeta lambdas/<clave>.
# Para añadir una nueva, ver "Cómo añadir una nueva función Lambda" en README.md (raíz).
lambdas = {
  countdown = {
    route_key = "GET /countdown"
  }

  birthday = {
    route_key = "GET /birthday"
  }
}
