# outputs.tf — Values consumed by downstream modules (storage, app service).

output "mysql_server_id" {
  description = "Resource ID of the MySQL Flexible Server."
  value       = azurerm_mysql_flexible_server.main.id
}

output "mysql_server_name" {
  description = "Name of the MySQL Flexible Server."
  value       = azurerm_mysql_flexible_server.main.name
}

output "mysql_server_fqdn" {
  description = "Fully qualified domain name (resolves via Private DNS inside VNet)."
  value       = azurerm_mysql_flexible_server.main.fqdn
}

output "mysql_database_name" {
  description = "Name of the application database."
  value       = azurerm_mysql_flexible_database.app.name
}

output "mysql_admin_username" {
  description = "Administrator login name."
  value       = azurerm_mysql_flexible_server.main.administrator_login
}

# ── Connection String (for App Service environment variables) ──
# Standard mysql:// URI format — compatible with mysql2 (Node.js), PyMySQL, and most other drivers.

output "mysql_connection_string" {
  description = "MySQL connection string template. Substitute <PASSWORD> at consumption time."
  value       = "mysql://${azurerm_mysql_flexible_server.main.administrator_login}:<PASSWORD>@${azurerm_mysql_flexible_server.main.fqdn}:3306/${azurerm_mysql_flexible_database.app.name}?ssl=true"
  sensitive   = true
}
