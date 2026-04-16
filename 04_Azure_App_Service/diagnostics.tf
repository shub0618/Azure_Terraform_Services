# diagnostics.tf — Diagnostic Settings for App Service
# Sends HTTP logs and app logs to Log Analytics.
# Set enable_diagnostics = true and provide workspace ID to activate.

resource "azurerm_monitor_diagnostic_setting" "appservice" {
  count                      = var.enable_diagnostics ? 1 : 0
  name                       = "diag-${var.web_app_name}"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
