# outputs.tf — Exported values for downstream Terraform projects

output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault for SDK/API access."
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_tenant_id" {
  description = "Tenant ID associated with the Key Vault."
  value       = azurerm_key_vault.main.tenant_id
}

output "private_endpoint_ip" {
  description = "Private IP address of the Key Vault Private Endpoint."
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.keyvault[0].private_service_connection[0].private_ip_address : null
}

output "app_service_keyvault_ref_format" {
  description = "Format for App Service Key Vault references in App Settings."
  value       = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=<SECRET-NAME>)"
}
