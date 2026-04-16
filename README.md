# Azure_Terraform_Services

A collection of modular Terraform projects for building a private, production-shaped Azure environment. Each module lives in its own numbered directory, owns its own state, and exposes outputs that the next module consumes via data sources.

Deploy them in order, or pick the ones you need — they're designed to stand alone where possible.

---

## Architecture

```
                       ┌──────────────────────────────────────┐
                       │         Azure Subscription           │
                       │                                      │
                       │   ┌────────────────────────────────┐ │
                       │   │   Resource Group               │ │
                       │   │                                │ │
                       │   │   ┌──────────────────────────┐ │ │
                       │   │   │  VNet  10.0.0.0/24       │ │ │
                       │   │   │                          │ │ │
                       │   │   │  ┌────────────────────┐  │ │ │
                       │   │   │  │ snet-appservice    │  │ │ │
                       │   │   │  │ 10.0.0.0/26        │──┼─┼─┼──► [App Service]  (future)
                       │   │   │  └────────────────────┘  │ │ │
                       │   │   │                          │ │ │
                       │   │   │  ┌────────────────────┐  │ │ │
                       │   │   │  │ snet-mysql         │  │ │ │
                       │   │   │  │ 10.0.0.64/26       │──┼─┼─┼──► [MySQL Flex]   (future)
                       │   │   │  └────────────────────┘  │ │ │
                       │   │   │                          │ │ │
                       │   │   │  ┌────────────────────┐  │ │ │
                       │   │   │  │ snet-privateendpts │  │ │ │
                       │   │   │  │ 10.0.0.128/27      │◄─┼─┼─┼── [Key Vault PE]  ✓ done
                       │   │   │  └────────────────────┘  │ │ │
                       │   │   │                          │ │ │
                       │   │   │  NSGs · Route Table ·    │ │ │
                       │   │   │  NAT Gateway (optional)  │ │ │
                       │   │   └──────────────────────────┘ │ │
                       │   │                                │ │
                       │   │   Private DNS zones:           │ │
                       │   │   · privatelink.vaultcore.     │ │
                       │   │   · privatelink.mysql.         │ │
                       │   │   · privatelink.blob.          │ │
                       │   └────────────────────────────────┘ │
                       └──────────────────────────────────────┘

                       Remote state: Azure Storage (per-module key)
```

---

## Modules

| # | Module | Status | Description |
|---|---|---|---|
| 01 | [`01_Azure_Vnet/`](./01_Azure_Vnet) | ✅ Available | VNet, 3 delegated subnets, NSGs, route table, optional NAT Gateway, Private DNS zones |
| 02 | [`02_Azure_KeyVaults/`](./02_Azure_KeyVaults) | ✅ Available | Key Vault with soft-delete + purge protection, optional Private Endpoint, diagnostic logging |
| 03 | `03_Azure_MySQL/` | 🚧 Coming soon | MySQL Flexible Server, VNet-integrated, with DB + user provisioning |
| 04 | `04_Azure_AppService/` | 🚧 Coming soon | App Service Plan + App Service with VNet integration, Managed Identity, Key Vault references |

---

## Deployment order

Modules share state through data sources — not remote state outputs — so each one looks up the previous module's resources by name from the same resource group. That keeps modules loosely coupled but means **order matters on first apply**:

```
01_Azure_Vnet  →  02_Azure_KeyVaults  →  03_Azure_MySQL  →  04_Azure_AppService
```

After they exist, you can re-apply any module independently.

---

## How the modules fit together

- **Each module has its own remote state file** (`vnet.terraform.tfstate`, `keyvault.terraform.tfstate`, etc.) in the same Azure Storage container. Blast radius of a mistake is one module, not the whole environment.
- **Shared contract: resource group name + VNet name.** Every downstream module takes `resource_group_name` and `vnet_name` as input variables and uses `data "azurerm_*"` to pull everything else it needs (subnet IDs, DNS zone IDs, etc.).
- **Every module creates resources with predictable names** (`snet-privateendpoints`, `privatelink.vaultcore.azure.net`, etc.) so the data-source lookups in the next module don't need to be parameterised to death.

This approach trades a bit of explicitness for a lot of simplicity — no `terraform_remote_state` data sources, no output-chaining hell, no tight coupling. Each module reads like a normal standalone Terraform project.

---

## Prerequisites

Before running any module:

1. **Azure subscription** and credentials discoverable by the `azurerm` provider (Azure CLI login, service principal env vars, or managed identity)
2. **Terraform `>= 1.3`** and `hashicorp/azurerm ~> 3.0`
3. **A Storage Account for remote state** (optional but recommended) — one container shared across all modules, one state key per module:
   ```bash
   az group create --name rg-terraform-state --location eastus2
   az storage account create --name <your-unique-name> --resource-group rg-terraform-state --location eastus2 --sku Standard_LRS
   az storage container create --name tfstate --account-name <your-unique-name>
   ```
   Then edit each module's `backend.tf` with the storage account name, or pass it via `-backend-config` at `terraform init` time.

---

## Quick start

Clone, configure, deploy in order:

```bash
git clone https://github.com/<your-user>/Azure_Terraform_Services.git
cd Azure_Terraform_Services

# Module 1 — VNet
cd 01_Azure_Vnet
cp terraform.tfvars.example terraform.tfvars   # edit as needed
terraform init
terraform apply

# Module 2 — Key Vault
cd ../02_Azure_KeyVaults
cp terraform.tfvars.example terraform.tfvars   # make sure key_vault_name is globally unique
terraform init
terraform apply
```

Each module's own README has the full variable reference and design notes.

---

## License

MIT — see [LICENSE](./LICENSE).
