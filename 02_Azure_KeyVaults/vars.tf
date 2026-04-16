# vars.tf — Input Variables
# Override defaults via terraform.tfvars or -var flags.

# ── General ──

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group (must match the VNet module's RG)."
  default     = "rg-demo-network"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    Environment = "Demo"
    Project     = "azure-keyvault-demo"
    ManagedBy   = "Terraform"
  }
}

# ── VNet References (must match the VNet module) ──

variable "vnet_name" {
  type        = string
  description = "Name of the existing Virtual Network."
  default     = "vnet-demo"
}

# ── Key Vault ──

variable "key_vault_name" {
  type        = string
  description = "Globally unique name for the Key Vault (3-24 chars, alphanumeric and hyphens)."
  default     = "kv-demo-001"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "Key Vault name must be 3-24 characters, start with a letter, and contain only alphanumeric characters and hyphens."
  }
}

variable "sku_name" {
  type        = string
  description = "SKU for Key Vault. 'standard' or 'premium' (includes HSM-backed keys)."
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU must be 'standard' or 'premium'."
  }
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Number of days to retain soft-deleted vaults and secrets (7-90)."
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Soft delete retention must be between 7 and 90 days."
  }
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Enable purge protection. Once enabled, cannot be disabled. Prevents permanent deletion during retention period."
  default     = true
}

variable "enable_rbac_authorization" {
  type        = bool
  description = "Use Azure RBAC for Key Vault data plane access instead of access policies."
  default     = false
}

variable "enabled_for_deployment" {
  type        = bool
  description = "Allow Azure VMs to retrieve certificates stored as secrets."
  default     = false
}

variable "enabled_for_disk_encryption" {
  type        = bool
  description = "Allow Azure Disk Encryption to retrieve secrets and unwrap keys."
  default     = false
}

variable "enabled_for_template_deployment" {
  type        = bool
  description = "Allow Azure Resource Manager to retrieve secrets."
  default     = false
}

# ── Network Access ──

variable "public_network_access_enabled" {
  type        = bool
  description = "Allow public network access. Set false for private-only access via Private Endpoint."
  default     = true
}

variable "network_acl_default_action" {
  type        = string
  description = "Default action for network ACLs: 'Allow' or 'Deny'."
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_acl_default_action)
    error_message = "Must be 'Allow' or 'Deny'."
  }
}

variable "network_acl_bypass" {
  type        = string
  description = "Which traffic can bypass network ACLs: 'AzureServices' or 'None'."
  default     = "AzureServices"

  validation {
    condition     = contains(["AzureServices", "None"], var.network_acl_bypass)
    error_message = "Must be 'AzureServices' or 'None'."
  }
}

variable "network_acl_ip_rules" {
  type        = list(string)
  description = "List of allowed public IP addresses or CIDR ranges."
  default     = []
}

# ── Private Endpoint ──

variable "enable_private_endpoint" {
  type        = bool
  description = "Create a Private Endpoint for the Key Vault in the Private Endpoints subnet."
  default     = false
}

# ── Access Policies ──
# Used when enable_rbac_authorization = false.
# Add policies for App Service Managed Identity, CI/CD OIDC SP, etc.

variable "access_policies" {
  type = list(object({
    object_id               = string
    secret_permissions      = list(string)
    key_permissions         = list(string)
    certificate_permissions = list(string)
  }))
  description = "List of access policies. Add after consumer identities (App Service MSI, OIDC SPs, etc.) exist."
  default     = []
}

# ── Diagnostics ──

variable "enable_diagnostics" {
  type        = bool
  description = "Enable diagnostic logging to Log Analytics."
  default     = false
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics workspace."
  default     = ""
}
