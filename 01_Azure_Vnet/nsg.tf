resource "azurerm_network_security_group" "appservice" {
  name                = "nsg-snet-appservice"
  location            = local.rg_location
  resource_group_name = local.rg_name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPS_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP_Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAll_Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "mysql" {
  name                = "nsg-snet-mysql"
  location            = local.rg_location
  resource_group_name = local.rg_name
  tags                = var.tags

  security_rule {
    name                       = "AllowMySQL_FromAppService"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = var.subnet_appservice_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAll_Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "privateendpoints" {
  name                = "nsg-snet-privateendpoints"
  location            = local.rg_location
  resource_group_name = local.rg_name
  tags                = var.tags

  security_rule {
    name                       = "AllowVNet_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAll_Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "appservice" {
  subnet_id                 = azurerm_subnet.appservice.id
  network_security_group_id = azurerm_network_security_group.appservice.id
}

resource "azurerm_subnet_network_security_group_association" "mysql" {
  subnet_id                 = azurerm_subnet.mysql.id
  network_security_group_id = azurerm_network_security_group.mysql.id
}

resource "azurerm_subnet_network_security_group_association" "privateendpoints" {
  subnet_id                 = azurerm_subnet.privateendpoints.id
  network_security_group_id = azurerm_network_security_group.privateendpoints.id
}
