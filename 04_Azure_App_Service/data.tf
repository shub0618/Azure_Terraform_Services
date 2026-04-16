# data.tf — Read outputs from upstream Terraform projects.
#
# This module consumes state from three upstream modules:
#   - 01_Azure_Vnet       → RG, subnet for VNet integration
#   - 02_Azure_KeyVaults  → Key Vault name (for secret references)
#   - 03_Azure_MySQL      → available if you want to wire MySQL outputs directly
#
# Edit the storage_account_name in each block below to match your setup.

# ── 01_Azure_Vnet remote state ──
data "terraform_remote_state" "vnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "REPLACE_WITH_YOUR_STORAGE_ACCOUNT"
    container_name       = "tfstate"
    key                  = "vnet.terraform.tfstate"
  }
}

# ── 03_Azure_MySQL remote state ──
data "terraform_remote_state" "mysql" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "REPLACE_WITH_YOUR_STORAGE_ACCOUNT"
    container_name       = "tfstate"
    key                  = "mysql.terraform.tfstate"
  }
}

# ── 02_Azure_KeyVaults remote state ──
data "terraform_remote_state" "keyvault" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "REPLACE_WITH_YOUR_STORAGE_ACCOUNT"
    container_name       = "tfstate"
    key                  = "keyvault.terraform.tfstate"
  }
}

locals {
  rg_name     = data.terraform_remote_state.vnet.outputs.resource_group_name
  rg_location = data.terraform_remote_state.vnet.outputs.resource_group_location

  subnet_appservice_id = data.terraform_remote_state.vnet.outputs.subnet_appservice_id
  vnet_name            = data.terraform_remote_state.vnet.outputs.vnet_name

  # Falls back to var.key_vault_name if the Key Vault module hasn't been applied yet.
  # This lets the App Service module deploy even without the Key Vault state present,
  # provided you pass the vault name explicitly via terraform.tfvars.
  key_vault_name = try(data.terraform_remote_state.keyvault.outputs.key_vault_name, var.key_vault_name)
}
