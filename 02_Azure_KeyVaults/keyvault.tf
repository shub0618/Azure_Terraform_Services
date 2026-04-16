# keyvault.tf — Azure Key Vault

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.sku_name

  # Soft Delete & Purge Protection
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Authorization Model
  enable_rbac_authorization = var.enable_rbac_authorization

  # VM / ARM Integration
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment

  # Network Access
  public_network_access_enabled = var.public_network_access_enabled

  network_acls {
    default_action = var.network_acl_default_action
    bypass         = var.network_acl_bypass
    ip_rules       = var.network_acl_ip_rules
  }

  tags = var.tags
}

# ── Deployer Access Policy ──
# Grants the identity running Terraform full access to manage secrets.
# This is the user/SP running 'terraform apply'.

resource "azurerm_key_vault_access_policy" "deployer" {
  count = var.enable_rbac_authorization ? 0 : 1

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Backup", "Delete", "Get", "List", "Purge",
    "Recover", "Restore", "Set"
  ]

  key_permissions = [
    "Backup", "Create", "Delete", "Get", "Import",
    "List", "Purge", "Recover", "Restore", "Update"
  ]

  certificate_permissions = [
    "Backup", "Create", "Delete", "Get", "Import",
    "List", "Purge", "Recover", "Restore", "Update"
  ]
}

# ── Additional Access Policies ──
# Add policies for App Service Managed Identity, CI/CD OIDC SPs, etc.
# Pass object_ids via the access_policies variable after those identities exist.

resource "azurerm_key_vault_access_policy" "additional" {
  count = var.enable_rbac_authorization ? 0 : length(var.access_policies)

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.access_policies[count.index].object_id

  secret_permissions      = var.access_policies[count.index].secret_permissions
  key_permissions         = var.access_policies[count.index].key_permissions
  certificate_permissions = var.access_policies[count.index].certificate_permissions
}
