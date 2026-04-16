# appservice.tf — App Service Plan + Web App

# ── App Service Plan (S1 Standard for autoscale + VNet) ──

resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  location            = local.rg_location
  resource_group_name = local.rg_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

# ── Web App (Node.js Backend) ──

resource "azurerm_linux_web_app" "main" {
  name                = var.web_app_name
  location            = local.rg_location
  resource_group_name = local.rg_name
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  # ── Managed Identity (for Key Vault access) ──
  dynamic "identity" {
    for_each = var.enable_managed_identity ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  # ── VNet Integration (private access to MySQL & Key Vault) ──
  virtual_network_subnet_id = local.subnet_appservice_id

  site_config {
    # ── Runtime ──
    application_stack {
      node_version = var.node_version
    }

    # ── Performance ──
    always_on                         = true
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    ftps_state                        = "Disabled"
    health_check_path                 = var.health_check_path
    health_check_eviction_time_in_min = 5

    # ── Stateless (no sticky sessions) ──
    # ARR Affinity disabled — backend is stateless, any instance can serve any request
  }

  # ── App Settings (Key Vault References) ──
  app_settings = {
    # Runtime
    "NODE_ENV"                     = "production"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~20"

    # Database (Key Vault references — resolved at startup via Managed Identity)
    "DB_HOST"     = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=DB-HOST)"
    "DB_USER"     = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=DB-USER)"
    "DB_PASSWORD" = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=DB-PASSWORD)"
    "DB_NAME"     = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=DB-NAME)"
    "DB_PORT"     = "3306"
    "DB_SSL"      = "true"

    # JWT (Key Vault references)
    "JWT_SECRET"     = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=JWT-SECRET)"
    "JWT_EXPIRES_IN" = "@Microsoft.KeyVault(VaultName=${local.key_vault_name};SecretName=JWT-EXPIRES-IN)"

    # Disable built-in App Service storage mount (not needed for stateless backend)
    "WEBSITE_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  # ── Logging ──
  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    application_logs {
      file_system_level = "Warning"
    }
  }

  lifecycle {
    ignore_changes = [
      # Prevent Terraform from overwriting app settings added via CLI/Portal
      # (e.g., additional secrets, App Insights key)
      app_settings["APPINSIGHTS_INSTRUMENTATIONKEY"],
      app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"],
    ]
  }
}

# ── Custom Domain Binding (optional) ──
# Only created when var.custom_domain is set. Requires DNS to be configured first.

resource "azurerm_app_service_custom_hostname_binding" "default" {
  count               = var.custom_domain != "" ? 1 : 0
  hostname            = var.custom_domain
  app_service_name    = azurerm_linux_web_app.main.name
  resource_group_name = local.rg_name
}
