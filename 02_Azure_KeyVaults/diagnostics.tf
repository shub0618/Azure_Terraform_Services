# diagnostics.tf — Diagnostic Settings for Key Vault
# Sends audit logs and metrics to Log Analytics.
# Set enable_diagnostics = true and provide workspace ID to activate.

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  count                      = var.enable_diagnostics ? 1 : 0
  name                       = "diag-${var.key_vault_name}"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
