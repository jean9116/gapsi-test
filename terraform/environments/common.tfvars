# Valores iguales en los tres ambientes. Lo que cambia por ambiente está en <env>/terraform.tfvars.
app_name = "pprov"
region   = "us-central1"
owner    = "jean"

notification_emails = ["jck9116@gmail.com"]

topics = {
  pedidos               = { push_path = "/events/pedidos" }
  entregas              = { push_path = "/events/entregas" }
  integraciones-entrada = { push_path = "/events/integraciones" }
  integraciones-salida  = {}
}

# Ejemplo de integración: un ERP externo publica en "integraciones-entrada"
# y consume lo que la plataforma deja en "integraciones-salida".
external_apps = {
  erp = {
    publish_topics = ["integraciones-entrada"]
    consume_topics = ["integraciones-salida"]
  }
}

app_secrets = {
  jwt-signing-key = { generate = true, accessors = ["api"] }
  erp-api-key     = { generate = false, accessors = ["worker", "batch"] }
}

jobs = {
  conciliacion = { schedule = "0 2 * * *", args = ["node", "jobs/conciliacion.js"] }
  reportes     = { schedule = "0 6 * * 1", args = ["node", "jobs/reportes.js"], memory = "2Gi" }
}

enable_cdn = true
enable_waf = true
