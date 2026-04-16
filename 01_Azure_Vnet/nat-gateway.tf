resource "azurerm_public_ip" "nat" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "pip-nat-${var.name_prefix}"
  location            = local.rg_location
  resource_group_name = local.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  count                   = var.enable_nat_gateway ? 1 : 0
  name                    = "natgw-${var.name_prefix}"
  location                = local.rg_location
  resource_group_name     = local.rg_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  count                = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.main[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "appservice" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.appservice.id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}
