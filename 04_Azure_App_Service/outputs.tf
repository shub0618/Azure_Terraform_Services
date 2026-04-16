# outputs.tf — Exported values for downstream projects and CI/CD.

output "app_service_id" {
  description = "Resource ID of the Web App."
  value       = azurerm_linux_web_app.main.id
}

output "app_service_name" {
  description = "Name of the Web App."
  value       = azurerm_linux_web_app.main.name
}

output "app_service_default_hostname" {
  description = "Default hostname (e.g., <app-name>.azurewebsites.net)."
  value       = azurerm_linux_web_app.main.default_hostname
}

output "app_service_url" {
  description = "Full HTTPS URL of the Web App."
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "managed_identity_principal_id" {
  description = "Principal ID of the system-assigned Managed Identity."
  value       = var.enable_managed_identity ? azurerm_linux_web_app.main.identity[0].principal_id : null
}

output "managed_identity_tenant_id" {
  description = "Tenant ID of the system-assigned Managed Identity."
  value       = var.enable_managed_identity ? azurerm_linux_web_app.main.identity[0].tenant_id : null
}

output "app_service_plan_id" {
  description = "Resource ID of the App Service Plan."
  value       = azurerm_service_plan.main.id
}

output "outbound_ip_addresses" {
  description = "Outbound IP addresses used by the App Service."
  value       = azurerm_linux_web_app.main.outbound_ip_addresses
}
