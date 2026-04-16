data "azurerm_resource_group" "existing" {
  count = var.use_existing_resource_group ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "main" {
  count    = var.use_existing_resource_group ? 0 : 1
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

locals {
  rg_name     = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.main[0].name
  rg_location = var.use_existing_resource_group ? data.azurerm_resource_group.existing[0].location : azurerm_resource_group.main[0].location
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = local.rg_location
  resource_group_name = local.rg_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "appservice" {
  name                 = "snet-appservice"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_appservice_cidr]

  delegation {
    name = "delegation-appservice"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "mysql" {
  name                 = "snet-mysql"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_mysql_cidr]

  delegation {
    name = "delegation-mysql"

    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "privateendpoints" {
  name                              = "snet-privateendpoints"
  resource_group_name               = local.rg_name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [var.subnet_privateendpoints_cidr]
  private_endpoint_network_policies = "Disabled"
}
