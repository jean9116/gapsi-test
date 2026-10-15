resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = "${var.name}-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

# Subred privada: Cloud Run (Direct VPC egress) y Cloud Run Jobs. Sin IPs públicas;
# Private Google Access para llegar a las APIs de Google sin salir a Internet.
resource "google_compute_subnetwork" "app" {
  project                  = var.project_id
  name                     = "${var.name}-subnet-app"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.app_subnet_cidr
  private_ip_google_access = true

  dynamic "log_config" {
    for_each = var.flow_logs_sampling > 0 ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = var.flow_logs_sampling
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# Private Service Access: Cloud SQL recibe una IP privada de este rango y no tiene IP pública.
resource "google_compute_global_address" "psa" {
  project       = var.project_id
  name          = "${var.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_prefix_length
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
  deletion_policy         = "ABANDON"
}

# Salida a Internet controlada (APIs de terceros de las integraciones) sin IPs públicas en las cargas.
resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "${var.name}-nat"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.app.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = var.nat_log_filter
  }
}

# La VPC custom ya niega todo el ingress por defecto. Se deja explícito y con logs
# para auditoría; solo se permite el health check de Google si en el futuro hay backends en VM/GKE.
resource "google_compute_firewall" "deny_all_ingress" {
  project   = var.project_id
  name      = "${var.name}-deny-all-ingress"
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
