# private-endpoint.tf — Private Endpoint for Key Vault
# Creates a private connection so Key Vault is only accessible within the VNet.
# Toggle with enable_private_endpoint variable.

resource "azurerm_private_endpoint" "keyvault" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "pe-${var.key_vault_name}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = data.azurerm_subnet.privateendpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "dns-${var.key_vault_name}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.keyvault.id]
  }
}
