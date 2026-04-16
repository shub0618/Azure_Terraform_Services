# mysql.tf — Azure MySQL Flexible Server (VNet-integrated)

resource "azurerm_mysql_flexible_server" "main" {
  name                = var.mysql_server_name
  location            = local.rg_location
  resource_group_name = local.rg_name

  # ── Authentication ──
  administrator_login    = var.mysql_admin_username
  administrator_password = var.mysql_admin_password

  # ── Engine ──
  version  = var.mysql_version
  sku_name = var.mysql_sku_name

  # ── Storage ──
  storage {
    size_gb           = var.mysql_storage_size_gb
    iops              = var.mysql_iops > 0 ? var.mysql_iops : null
    auto_grow_enabled = var.mysql_auto_grow_enabled
  }

  # ── Networking (Private Access via VNet) ──
  delegated_subnet_id = local.subnet_mysql_id
  private_dns_zone_id = local.private_dns_zone_mysql_id

  # ── Backup ──
  backup_retention_days        = var.mysql_backup_retention_days
  geo_redundant_backup_enabled = var.mysql_geo_redundant_backup

  # ── High Availability ──
  dynamic "high_availability" {
    for_each = var.mysql_ha_mode != "Disabled" ? [1] : []
    content {
      mode = var.mysql_ha_mode
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Prevent Terraform from resetting the password on every apply
      administrator_password
    ]
  }
}

# ── Application Database ──

resource "azurerm_mysql_flexible_database" "app" {
  name                = var.mysql_database_name
  resource_group_name = local.rg_name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = var.mysql_charset
  collation           = var.mysql_collation
}

# ── Server Parameters (Performance & Security) ──

resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = local.rg_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "ON"
}

resource "azurerm_mysql_flexible_server_configuration" "tls_version" {
  name                = "tls_version"
  resource_group_name = local.rg_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "TLSv1.2,TLSv1.3"
}

resource "azurerm_mysql_flexible_server_configuration" "slow_query_log" {
  name                = "slow_query_log"
  resource_group_name = local.rg_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "ON"
}

resource "azurerm_mysql_flexible_server_configuration" "long_query_time" {
  name                = "long_query_time"
  resource_group_name = local.rg_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "2"
}

resource "azurerm_mysql_flexible_server_configuration" "audit_log_enabled" {
  name                = "audit_log_enabled"
  resource_group_name = local.rg_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "ON"
}

resource "azurerm_mysql_flexible_server_configuration" "audit_log_events" {
  name                = "audit_log_events"
  resource_group_name = local.rg_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "CONNECTION,DCL,DDL"
}

# ── Connection Limits ──
# 10 connections/instance × 8 max autoscale instances = 80
# + 40 buffer for admin, monitoring, Cloud Shell = 120

resource "azurerm_mysql_flexible_server_configuration" "max_connections" {
  name                = "max_connections"
  resource_group_name = local.rg_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "120"
}
