variable "project_id" {
  description = "Proyecto GCP del ambiente."
  type        = string
}

variable "region" {
  description = "Región del servicio."
  type        = string
}

variable "name" {
  description = "Nombre del servicio Cloud Run."
  type        = string
}

variable "image" {
  description = "Imagen inicial. Después la cambia el pipeline de CI/CD (Terraform ignora la imagen)."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "service_account_email" {
  description = "Service account de runtime."
  type        = string
}

variable "ingress" {
  description = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER (solo vía LB), INGRESS_TRAFFIC_INTERNAL_ONLY o INGRESS_TRAFFIC_ALL."
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
}

variable "public_via_lb" {
  description = "Sin IAM de invocación (la autenticación la hace la app). Solo con ingress restringido al LB."
  type        = bool
  default     = false
}

variable "invokers" {
  description = "Miembros con roles/run.invoker (p. ej. la SA de push de Pub/Sub)."
  type        = map(string)
  default     = {}
}

variable "port" {
  description = "Puerto del contenedor."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "vCPU por instancia."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memoria por instancia."
  type        = string
  default     = "512Mi"
}

variable "cpu_always_allocated" {
  description = "true = facturación por instancia (CPU siempre asignada); false = solo durante peticiones."
  type        = bool
  default     = false
}

variable "min_instances" {
  description = "Instancias mínimas (evitan arranque en frío)."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Tope de escalado (protege la BD y el coste)."
  type        = number
  default     = 10
}

variable "concurrency" {
  description = "Peticiones simultáneas por instancia."
  type        = number
  default     = 80
}

variable "timeout_seconds" {
  description = "Timeout de petición."
  type        = number
  default     = 60
}

variable "env" {
  description = "Variables de entorno en claro (nada sensible)."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Variables de entorno desde Secret Manager: NOMBRE => secret_id."
  type        = map(string)
  default     = {}
}

variable "vpc_network" {
  description = "VPC para Direct VPC egress (null = sin VPC)."
  type        = string
  default     = null
}

variable "vpc_subnetwork" {
  description = "Subred para Direct VPC egress."
  type        = string
  default     = null
}

variable "vpc_egress" {
  description = "PRIVATE_RANGES_ONLY o ALL_TRAFFIC (todo por Cloud NAT)."
  type        = string
  default     = "PRIVATE_RANGES_ONLY"
}

variable "health_path" {
  description = "Ruta de los probes de arranque y vida (null = probe TCP por defecto)."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protege el servicio contra borrado."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels comunes."
  type        = map(string)
  default     = {}
}
