# keyvault-access.tf — Grant App Service Managed Identity access to Key Vault
# This creates the access policy so the App Service can read secrets at runtime.

data "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  resource_group_name = local.rg_name
}

resource "azurerm_key_vault_access_policy" "appservice" {
  count = var.enable_managed_identity ? 1 : 0

  key_vault_id = data.azurerm_key_vault.main.id
  tenant_id    = azurerm_linux_web_app.main.identity[0].tenant_id
  object_id    = azurerm_linux_web_app.main.identity[0].principal_id

  # App Service only needs GET — principle of least privilege
  secret_permissions = ["Get"]

  key_permissions         = []
  certificate_permissions = []
}
