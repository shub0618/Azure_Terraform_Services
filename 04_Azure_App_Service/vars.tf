# vars.tf — App Service Variables
# Override defaults via terraform.tfvars or -var flags.

# ── App Service Plan ──

variable "app_service_plan_name" {
  type        = string
  description = "Name of the App Service Plan."
  default     = "asp-demo"
}

variable "app_service_plan_sku" {
  type        = string
  description = "SKU for the App Service Plan. S1 supports autoscale + VNet integration."
  default     = "S1"

  validation {
    condition     = contains(["B1", "B2", "B3", "S1", "S2", "S3", "P1v2", "P2v2", "P3v2", "P1v3", "P2v3", "P3v3"], var.app_service_plan_sku)
    error_message = "Must be a valid App Service Plan SKU."
  }
}

# ── Web App ──

variable "web_app_name" {
  type        = string
  description = "Globally unique name for the Web App."
  default     = "api-demo-001"
}

variable "node_version" {
  type        = string
  description = "Node.js runtime version."
  default     = "20-lts"
}

# ── Identity ──

variable "enable_managed_identity" {
  type        = bool
  description = "Enable system-assigned Managed Identity for Key Vault access."
  default     = true
}

# ── Key Vault Integration ──

variable "key_vault_name" {
  type        = string
  description = "Name of the Key Vault for secret references. Used as a fallback when the Key Vault module's remote state is not available."
  default     = "kv-demo-001"
}

# ── Health Check ──

variable "health_check_path" {
  type        = string
  description = "Path for Azure health check probe."
  default     = "/api/health"
}

# ── Autoscale ──

variable "enable_autoscale" {
  type        = bool
  description = "Enable autoscale rules. Requires S1 or higher SKU."
  default     = true
}

variable "autoscale_min_instances" {
  type        = number
  description = "Minimum number of instances (2 for high availability)."
  default     = 2

  validation {
    condition     = var.autoscale_min_instances >= 1 && var.autoscale_min_instances <= 10
    error_message = "Min instances must be between 1 and 10."
  }
}

variable "autoscale_max_instances" {
  type        = number
  description = "Maximum number of instances (cost ceiling)."
  default     = 8

  validation {
    condition     = var.autoscale_max_instances >= 1 && var.autoscale_max_instances <= 30
    error_message = "Max instances must be between 1 and 30."
  }
}

variable "autoscale_default_instances" {
  type        = number
  description = "Default number of instances when no metrics available."
  default     = 2
}

# ── Custom Domain (optional) ──

variable "custom_domain" {
  type        = string
  description = "Custom domain name (e.g., api.example.com). Leave empty to skip."
  default     = ""
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

# ── Tags ──

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default = {
    Environment = "Demo"
    Project     = "azure-appservice-demo"
    ManagedBy   = "Terraform"
  }
}
