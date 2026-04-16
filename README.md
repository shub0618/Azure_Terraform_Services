# Azure_Terraform_Services

A collection of modular Terraform projects for building a private, production-shaped Azure environment — VNet with delegated subnets, Key Vault with Private Endpoints, MySQL Flexible Server with VNet integration, and an App Service that ties it all together via Managed Identity.

Each module lives in its own numbered directory, owns its own state, and consumes the previous module's resources — either via `terraform_remote_state` or via named data-source lookups. Deploy them in order, or pick the ones you need.

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
                       │   │   │  │ 10.0.0.0/26        │◄─┼─┼─┼── [App Service]   ✓ done
                       │   │   │  └────────────────────┘  │ │ │        │  │
                       │   │   │                          │ │ │        │  │ MI + KV refs
                       │   │   │  ┌────────────────────┐  │ │ │        │  ▼
                       │   │   │  │ snet-mysql         │  │ │ │        │  (Key Vault)
                       │   │   │  │ 10.0.0.64/26       │◄─┼─┼─┼────────┘
                       │   │   │  └────────────────────┘  │ │ │    MySQL conn
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
                       │   │   Resources in RG:             │ │
                       │   │   · MySQL Flexible Server   ✓  │ │
                       │   │   · Key Vault               ✓  │ │
                       │   │   · App Service Plan + App  ✓  │ │
                       │   │                                │ │
                       │   │   Private DNS zones:           │ │
                       │   │   · privatelink.vaultcore.     │ │
                       │   │   · privatelink.mysql.         │ │
                       │   │   · privatelink.blob.          │ │
                       │   └────────────────────────────────┘ │
                       └──────────────────────────────────────┘

                       Remote state: Azure Storage (per-module key)
```

Traffic flow at runtime:
```
Client ──HTTPS──► App Service ──VNet integration──► snet-appservice
                       │
                       ├──► MySQL Flex (private, via snet-mysql + private DNS)
                       │
                       └──► Key Vault (private, via PE in snet-privateendpoints)
                                     read secrets using System-Assigned Managed Identity
```

---

## Modules

| # | Module | Status | Description |
|---|---|---|---|
| 01 | [`01_Azure_Vnet/`](./01_Azure_Vnet) | ✅ Available | VNet, 3 delegated subnets, NSGs, route table, optional NAT Gateway, Private DNS zones |
| 02 | [`02_Azure_KeyVaults/`](./02_Azure_KeyVaults) | ✅ Available | Key Vault with soft-delete + purge protection, optional Private Endpoint, diagnostic logging |
| 03 | [`03_Azure_MySQL/`](./03_Azure_MySQL) | ✅ Available | MySQL Flexible Server, VNet-integrated, hardened parameters, application database |
| 04 | [`04_Azure_AppService/`](./04_Azure_AppService) | ✅ Available | Linux App Service with VNet integration, Managed Identity → Key Vault, autoscale, health checks |

---

## Deployment order

Each downstream module reads the previous module's state, so **order matters on first apply**:

```
01_Azure_Vnet  →  02_Azure_KeyVaults  →  03_Azure_MySQL  →  04_Azure_AppService
```

After they all exist, you can re-apply any module independently.

---

## How the modules fit together

Two patterns show up across the modules for consuming upstream state — both are deliberate, and both have trade-offs worth knowing:

1. **`terraform_remote_state` data source** (used by `03_Azure_MySQL` and `04_Azure_AppService`)
   Reads several outputs from an upstream module's state file in one go. Cleaner when a module needs many pieces of upstream state — RG, subnet ID, DNS zone ID from a map — in a single shot. The App Service module uses this to pull from *three* upstream modules at once.

2. **Named `data "azurerm_*"` lookups** (used by `02_Azure_KeyVaults`)
   Each resource is looked up by its known name in Azure (`snet-privateendpoints`, `privatelink.vaultcore.azure.net`, etc.). Looser coupling — the downstream module doesn't need to know where the upstream module stored its state. Works even if upstream state lives in a different backend.

Neither is universally right. The MySQL and App Service modules pick `terraform_remote_state` because they each read five-plus things from upstream (map lookups included); the Key Vault module uses named lookups because it only reads two.

### Other shared conventions

- **Each module has its own remote state file** (`vnet.terraform.tfstate`, `keyvault.terraform.tfstate`, `mysql.terraform.tfstate`, `appservice.terraform.tfstate`) in the same Azure Storage container. Blast radius of a mistake is one module, not the whole environment.
- **Shared contract: resource group name + VNet name** — every module takes these as inputs (or reads them from upstream state).
- **Predictable resource names** — `snet-privateendpoints`, `privatelink.vaultcore.azure.net`, etc. — so data-source lookups don't need to be parameterised to death.
- **Secrets never in tfvars** — the MySQL admin password is passed via `TF_VAR_*` environment variables; app secrets live in Key Vault and are injected into the App Service via `@Microsoft.KeyVault(...)` references resolved at startup by Managed Identity.

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
   Then edit each module's `backend.tf` (and for modules that use `terraform_remote_state`, their `data.tf`) with the storage account name.

---

## Quick start

```bash
git clone https://github.com/<your-user>/Azure_Terraform_Services.git
cd Azure_Terraform_Services

# Module 1 — VNet
cd 01_Azure_Vnet
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# Module 2 — Key Vault
cd ../02_Azure_KeyVaults
cp terraform.tfvars.example terraform.tfvars   # key_vault_name must be globally unique
terraform init && terraform apply

# Module 3 — MySQL
cd ../03_Azure_MySQL
cp terraform.tfvars.example terraform.tfvars   # mysql_server_name must be globally unique
export TF_VAR_mysql_admin_password='YourStr0ng!Pass#here'
terraform init && terraform apply

# Seed Key Vault with app secrets (use MySQL outputs)
az keyvault secret set --vault-name <vault> --name DB-HOST     --value "$(terraform -chdir=../03_Azure_MySQL output -raw mysql_server_fqdn)"
az keyvault secret set --vault-name <vault> --name DB-USER     --value "$(terraform -chdir=../03_Azure_MySQL output -raw mysql_admin_username)"
az keyvault secret set --vault-name <vault> --name DB-PASSWORD --value "$TF_VAR_mysql_admin_password"
az keyvault secret set --vault-name <vault> --name DB-NAME     --value "$(terraform -chdir=../03_Azure_MySQL output -raw mysql_database_name)"
az keyvault secret set --vault-name <vault> --name JWT-SECRET  --value "$(openssl rand -hex 32)"
az keyvault secret set --vault-name <vault> --name JWT-EXPIRES-IN --value "24h"

# Module 4 — App Service
cd ../04_Azure_AppService
cp terraform.tfvars.example terraform.tfvars   # web_app_name must be globally unique
terraform init && terraform apply

# Deploy your code (example for a zip deploy)
az webapp deploy --resource-group <rg> --name <app-name> --src-path ./dist.zip --type zip
```

Each module's own README has the full variable reference, design notes, and cost estimates.

---

## Cost & cleanup

The biggest line items in this stack:

| Resource | Monthly (approx) |
|---|---|
| App Service Plan S1 × 2 instances | ~$140 |
| MySQL Flexible Server B1ms | ~$16 |
| Key Vault Standard | < $1 + per-operation |
| NAT Gateway (if enabled) | ~$32 + egress |
| Storage (state + backups) | < $5 |

**Run `terraform destroy` in reverse order when you're done**: `04 → 03 → 02 → 01`. MySQL and the App Service Plan are the two resources that rack up real cost if forgotten.

---

## License

MIT — see [LICENSE](./LICENSE).
