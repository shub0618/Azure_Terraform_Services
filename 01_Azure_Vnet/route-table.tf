resource "azurerm_route_table" "main" {
  name                = "rt-${var.name_prefix}"
  location            = local.rg_location
  resource_group_name = local.rg_name
  tags                = var.tags

  route {
    name           = "default-internet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "appservice" {
  subnet_id      = azurerm_subnet.appservice.id
  route_table_id = azurerm_route_table.main.id
}

resource "azurerm_subnet_route_table_association" "mysql" {
  subnet_id      = azurerm_subnet.mysql.id
  route_table_id = azurerm_route_table.main.id
}

resource "azurerm_subnet_route_table_association" "privateendpoints" {
  subnet_id      = azurerm_subnet.privateendpoints.id
  route_table_id = azurerm_route_table.main.id
}
