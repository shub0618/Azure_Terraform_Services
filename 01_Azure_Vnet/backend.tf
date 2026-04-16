# Remote state backend (Azure Storage).
# Fill these in with your own values, or initialize via `-backend-config` flags:
#   terraform init \
#     -backend-config="resource_group_name=<your-rg>" \
#     -backend-config="storage_account_name=<your-storage-account>" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=vnet.terraform.tfstate"
#
# Comment this block out if you want to use local state while experimenting.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "REPLACE_WITH_YOUR_STORAGE_ACCOUNT"
    container_name       = "tfstate"
    key                  = "vnet.terraform.tfstate"
  }
}
