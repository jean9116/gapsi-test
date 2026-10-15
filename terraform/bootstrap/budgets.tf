# Aviso al 50 %, 90 % y 100 % del gasto real y al 100 % del previsto. Por defecto avisa
# a los administradores de facturación por correo.
resource "google_billing_budget" "this" {
  provider = google.billing
  for_each = merge({ shared = var.shared_budget_usd }, { for e, cfg in var.environments : e => cfg.budget_usd })

  billing_account = var.billing_account
  display_name    = "${local.projects[each.key]} mensual"

  budget_filter {
    projects               = ["projects/${google_project.this[each.key].number}"]
    calendar_period        = "MONTH"
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(each.value)
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [google_project_service.shared]
}
