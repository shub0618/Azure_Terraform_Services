# vars.tf — Input Variables
# Override defaults via terraform.tfvars or -var flags.

# ── General ──

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group."
  default     = "rg-demo-network"
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "East US 2"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    Environment = "Demo"
    Project     = "azure-vnet-demo"
    ManagedBy   = "Terraform"
  }
}

# ── Existing Resource Group ──
# Set true  → uses data source to reference an already-created RG.
# Set false → Terraform creates a new RG.

variable "use_existing_resource_group" {
  type    = bool
  default = false
}

# ── Virtual Network ──

variable "vnet_name" {
  type        = string
  description = "Name of the Virtual Network."
  default     = "vnet-demo"
}

variable "vnet_cidr" {
  type        = string
  description = "Address space for the VNet (CIDR)."
  default     = "10.0.0.0/24"

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "Must be a valid CIDR block (e.g. 10.0.0.0/24)."
  }
}

# ── Subnets ──
#  10.0.0.0/26    → App Service       (64 IPs)
#  10.0.0.64/26   → MySQL Flexible    (64 IPs)
#  10.0.0.128/27  → Private Endpoints (32 IPs)

variable "subnet_appservice_cidr" {
  type    = string
  default = "10.0.0.0/26"
}

variable "subnet_mysql_cidr" {
  type    = string
  default = "10.0.0.64/26"
}

variable "subnet_privateendpoints_cidr" {
  type    = string
  default = "10.0.0.128/27"
}

# ── NAT Gateway ──
# Provides a static outbound public IP for all subnets.
# Useful for whitelisting your app's outbound IP.

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

# ── Resource Name Prefix ──
# Used as a prefix for resources that require globally- or regionally-unique names
# (NAT Gateway, Public IP, Route Table). Keep it short and lowercase.

variable "name_prefix" {
  type        = string
  description = "Short prefix used in resource names (e.g. 'demo', 'myapp')."
  default     = "demo"
}

# ── Private DNS Zones ──
# Required for Private Endpoints to resolve internal Azure service names.
# Defaults cover: MySQL Flexible Server, Blob Storage, Key Vault.

variable "private_dns_zones" {
  type        = list(string)
  description = "List of Private DNS zone names to create and link to the VNet."
  default = [
    "privatelink.mysql.database.azure.com",
    "privatelink.blob.core.windows.net",
    "privatelink.vaultcore.azure.net"
  ]
}
