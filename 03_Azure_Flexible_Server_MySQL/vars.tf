# vars.tf — MySQL Flexible Server Variables
# Override defaults via terraform.tfvars or -var flags.

# ── Location ──
# Note: this module uses the location inherited from the VNet module via
# remote state (local.rg_location). This variable is retained for cases where
# you want to deploy MySQL in a different region from the VNet; wire it into
# mysql.tf's `location` argument if you need that.

variable "mysql_location" {
  type        = string
  description = "Azure region for MySQL. Can differ from VNet region."
  default     = "eastus2"
}

# ── Server ──

variable "mysql_server_name" {
  type        = string
  description = "Name of the MySQL Flexible Server (must be globally unique)."
  default     = "mysql-demo-001"
}

variable "mysql_version" {
  type        = string
  description = "MySQL engine version."
  default     = "8.0.21"

  validation {
    condition     = contains(["5.7", "8.0.21"], var.mysql_version)
    error_message = "Supported versions: 5.7, 8.0.21."
  }
}

# ── SKU / Sizing ──
# Burstable B1ms = 1 vCore, 2 GB RAM (~$16/month)
# Burstable B2s  = 2 vCores, 4 GB RAM (~$32/month)

variable "mysql_sku_name" {
  type        = string
  description = "SKU name for the Flexible Server."
  default     = "B_Standard_B2s"
}

variable "mysql_storage_size_gb" {
  type        = number
  description = "Storage allocated in GB."
  default     = 20

  validation {
    condition     = var.mysql_storage_size_gb >= 20 && var.mysql_storage_size_gb <= 16384
    error_message = "Storage must be between 20 and 16384 GB."
  }
}

variable "mysql_iops" {
  type        = number
  description = "Provisioned IOPS. 0 = use free bundled IOPS (360 for 20 GB)."
  default     = 0
}

variable "mysql_auto_grow_enabled" {
  type        = bool
  description = "Enable storage auto-grow when nearing capacity."
  default     = true
}

# ── Authentication ──

variable "mysql_admin_username" {
  type        = string
  description = "Administrator login name."
  default     = "mysqladmin"

  validation {
    condition     = !contains(["admin", "administrator", "root", "sa", "azure_superuser"], lower(var.mysql_admin_username))
    error_message = "Username cannot be a reserved word."
  }
}

variable "mysql_admin_password" {
  type        = string
  description = "Administrator password (min 8 chars, must include upper, lower, number or special). Pass via TF_VAR_mysql_admin_password environment variable — never commit."
  sensitive   = true
}

# ── Networking ──

variable "mysql_public_access" {
  type        = bool
  description = "Enable public network access. Set false for VNet-only."
  default     = false
}

# ── Backup ──

variable "mysql_backup_retention_days" {
  type        = number
  description = "Number of days to retain backups (1–35)."
  default     = 7

  validation {
    condition     = var.mysql_backup_retention_days >= 1 && var.mysql_backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "mysql_geo_redundant_backup" {
  type        = bool
  description = "Enable geo-redundant backups (not available on Burstable SKU)."
  default     = false
}

# ── High Availability ──

variable "mysql_ha_mode" {
  type        = string
  description = "HA mode: Disabled, SameZone, or ZoneRedundant."
  default     = "Disabled"

  validation {
    condition     = contains(["Disabled", "SameZone", "ZoneRedundant"], var.mysql_ha_mode)
    error_message = "Must be Disabled, SameZone, or ZoneRedundant."
  }
}

# ── Database ──

variable "mysql_database_name" {
  type        = string
  description = "Name of the application database to create."
  default     = "appdb"
}

variable "mysql_charset" {
  type    = string
  default = "utf8mb4"
}

variable "mysql_collation" {
  type    = string
  default = "utf8mb4_unicode_ci"
}

# ── Tags ──

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    Environment = "Demo"
    Project     = "azure-mysql-demo"
    ManagedBy   = "Terraform"
  }
}
