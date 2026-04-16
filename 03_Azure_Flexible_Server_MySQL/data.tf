# data.tf — Read outputs from the 01_Azure_Vnet module's remote state.
#
# Unlike the Key Vault module (which uses data sources by resource name),
# this module consumes the VNet's outputs directly via terraform_remote_state.
# Both approaches work — this one is tighter when the downstream module needs
# several pieces of state (subnet ID, DNS zone ID map, etc.) in one shot.

data "terraform_remote_state" "vnet" {
  backend = "azurerm"

  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "REPLACE_WITH_YOUR_STORAGE_ACCOUNT"
    container_name       = "tfstate"
    key                  = "vnet.terraform.tfstate"
  }
}

locals {
  rg_name     = data.terraform_remote_state.vnet.outputs.resource_group_name
  rg_location = data.terraform_remote_state.vnet.outputs.resource_group_location
  vnet_id     = data.terraform_remote_state.vnet.outputs.vnet_id
  vnet_name   = data.terraform_remote_state.vnet.outputs.vnet_name

  subnet_mysql_id           = data.terraform_remote_state.vnet.outputs.subnet_mysql_id
  private_dns_zone_mysql_id = data.terraform_remote_state.vnet.outputs.private_dns_zone_ids["privatelink.mysql.database.azure.com"]
}
