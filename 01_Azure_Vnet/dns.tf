resource "azurerm_private_dns_zone" "zones" {
  for_each            = toset(var.private_dns_zones)
  name                = each.value
  resource_group_name = local.rg_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = toset(var.private_dns_zones)
  name                  = "dnslink-${replace(each.value, ".", "-")}"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}
