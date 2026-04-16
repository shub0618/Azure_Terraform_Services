output "resource_group_name" {
  value = local.rg_name
}

output "resource_group_location" {
  value = local.rg_location
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_appservice_id" {
  value = azurerm_subnet.appservice.id
}

output "subnet_mysql_id" {
  value = azurerm_subnet.mysql.id
}

output "subnet_privateendpoints_id" {
  value = azurerm_subnet.privateendpoints.id
}

output "nsg_appservice_id" {
  value = azurerm_network_security_group.appservice.id
}

output "nsg_mysql_id" {
  value = azurerm_network_security_group.mysql.id
}

output "nsg_privateendpoints_id" {
  value = azurerm_network_security_group.privateendpoints.id
}

output "route_table_id" {
  value = azurerm_route_table.main.id
}

output "nat_gateway_public_ip" {
  value = var.enable_nat_gateway ? azurerm_public_ip.nat[0].ip_address : null
}

output "private_dns_zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
}
