resource "google_compute_global_address" "this" {
  project = var.project_id
  name    = "${var.name}-lb-ip"
}

locals {
  domain = coalesce(var.domain, "${replace(google_compute_global_address.this.address, ".", "-")}.sslip.io")
}

resource "google_compute_region_network_endpoint_group" "frontend" {
  project               = var.project_id
  name                  = "${var.name}-frontend-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.frontend_service_name
  }
}

resource "google_compute_region_network_endpoint_group" "api" {
  project               = var.project_id
  name                  = "${var.name}-api-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.api_service_name
  }
}

# --- Cloud Armor: WAF + rate limiting por IP delante de frontend y API ---
resource "google_compute_security_policy" "this" {
  #checkov:skip=CKV_GCP_73:cve-canary (Log4j) va en las reglas WAF dinámicas, que checkov no evalúa
  project = var.project_id
  name    = "${var.name}-armor"
  type    = "CLOUD_ARMOR"

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }

  dynamic "rule" {
    for_each = var.enable_waf ? {
      1000 = "sqli-v33-stable"
      1001 = "xss-v33-stable"
      1002 = "lfi-v33-stable"
      1003 = "rce-v33-stable"
      1004 = "cve-canary"
    } : {}
    content {
      action   = "deny(403)"
      priority = rule.key
      match {
        expr {
          expression = "evaluatePreconfiguredWaf('${rule.value}', {'sensitivity': 1})"
        }
      }
      description = "WAF ${rule.value}"
    }
  }

  rule {
    action   = "throttle"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_per_minute
        interval_sec = 60
      }
    }
    description = "Rate limit por IP"
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Regla por defecto"
  }
}

resource "google_compute_backend_service" "frontend" {
  project               = var.project_id
  name                  = "${var.name}-frontend-be"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = google_compute_security_policy.this.id
  enable_cdn            = var.enable_cdn

  backend {
    group = google_compute_region_network_endpoint_group.frontend.id
  }

  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode        = "CACHE_ALL_STATIC"
      default_ttl       = 3600
      client_ttl        = 3600
      max_ttl           = 86400
      negative_caching  = true
      serve_while_stale = 86400

      cache_key_policy {
        include_host         = true
        include_protocol     = true
        include_query_string = true
      }
    }
  }

  log_config {
    enable      = true
    sample_rate = var.log_sample_rate
  }
}

resource "google_compute_backend_service" "api" {
  project               = var.project_id
  name                  = "${var.name}-api-be"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = google_compute_security_policy.this.id
  enable_cdn            = false

  backend {
    group = google_compute_region_network_endpoint_group.api.id
  }

  log_config {
    enable      = true
    sample_rate = var.log_sample_rate
  }
}

resource "google_compute_url_map" "https" {
  project         = var.project_id
  name            = "${var.name}-urlmap"
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "main"
  }

  path_matcher {
    name            = "main"
    default_service = google_compute_backend_service.frontend.id

    path_rule {
      paths   = [var.api_path_prefix, "${var.api_path_prefix}/*"]
      service = google_compute_backend_service.api.id
    }
  }
}

resource "google_compute_managed_ssl_certificate" "this" {
  project = var.project_id
  name    = "${var.name}-cert-${substr(md5(local.domain), 0, 6)}"

  managed {
    domains = [local.domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_ssl_policy" "this" {
  project         = var.project_id
  name            = "${var.name}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "this" {
  project          = var.project_id
  name             = "${var.name}-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
  ssl_policy       = google_compute_ssl_policy.this.id
}

resource "google_compute_global_forwarding_rule" "https" {
  project               = var.project_id
  name                  = "${var.name}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.this.id
}

# HTTP solo redirige a HTTPS.
resource "google_compute_url_map" "redirect" {
  project = var.project_id
  name    = "${var.name}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  project = var.project_id
  name    = "${var.name}-http-proxy"
  url_map = google_compute_url_map.redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project_id
  name                  = "${var.name}-http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
}
