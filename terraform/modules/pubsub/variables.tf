variable "project_id" {
  description = "Proyecto GCP del ambiente."
  type        = string
}

variable "name" {
  description = "Prefijo de nombres (<app>-<env>)."
  type        = string
}

variable "topics" {
  description = <<-EOT
    Topics de eventos. Cada uno tiene su DLQ. Si push_path no es null, se crea una suscripción
    push autenticada (OIDC) hacia el worker en esa ruta.
  EOT
  type = map(object({
    push_path = optional(string)
  }))
}

variable "worker_url" {
  description = "URL del servicio worker (destino de las suscripciones push)."
  type        = string
}

variable "push_invoker_email" {
  description = "Service account con la que Pub/Sub firma el token OIDC hacia el worker."
  type        = string
}

variable "publishers" {
  description = "Miembros internos que publican en todos los topics (api, worker, batch)."
  type        = map(string)
  default     = {}
}

variable "external_apps" {
  description = <<-EOT
    Aplicaciones externas que intercambian mensajes. Cada una recibe su propia service account:
    publica en publish_topics y consume (pull) de una suscripción propia en consume_topics.
  EOT
  type = map(object({
    publish_topics = optional(list(string), [])
    consume_topics = optional(list(string), [])
  }))
  default = {}
}

variable "max_delivery_attempts" {
  description = "Intentos antes de mandar el mensaje a la DLQ (5-100)."
  type        = number
  default     = 5
}

variable "ack_deadline_seconds" {
  description = "Tiempo que tiene el consumidor para confirmar un mensaje."
  type        = number
  default     = 60
}

variable "message_retention" {
  description = "Retención de mensajes no confirmados."
  type        = string
  default     = "604800s"
}

variable "labels" {
  description = "Labels comunes."
  type        = map(string)
  default     = {}
}
