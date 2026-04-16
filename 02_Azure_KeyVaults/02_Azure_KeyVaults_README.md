# 02_Azure_KeyVaults

A reference Terraform module for provisioning an **Azure Key Vault** with production-grade defaults: soft-delete, purge protection, tunable network ACLs, optional Private Endpoint, diagnostic logging to Log Analytics, and support for both access-policy and RBAC authorization models.

> Module 2 of the [Azure_Terraform_Services](../README.md) series. Assumes the [VNet module](../01_Azure_Vnet) has been deployed first — it looks up the RG, `snet-privateendpoints` subnet, and `privatelink.vaultcore.azure.net` DNS zone via data sources. Also runs standalone if you disable the Private Endpoint.

---

## What this creates

| Resource | Purpose |
|---|---|
| Key Vault | Soft-delete (90d), purge protection on, both auth models supported |
| Deployer access policy | Grants the identity running `terraform apply` full secret/key/cert permissions (access-policy mode only) |
| Additional access policies | For App Service Managed Identity, CI/CD OIDC SP, etc. — passed as a list |
| Private Endpoint *(optional)* | Private IP in `snet-privateendpoints`, auto-registered in `privatelink.vaultcore.azure.net` |
| Diagnostic Setting *(optional)* | Ships `AuditEvent`, `AzurePolicyEvaluationDetails`, and `AllMetrics` to Log Analytics |

---

## File layout

```
.
├── provider.tf           # azurerm provider with key_vault feature block (safe defaults)
├── backend.tf            # remote state on Azure Storage (edit before init)
├── vars.tf               # all inputs with validations and sensible defaults
├── data.tf               # references RG, VNet, PE subnet, DNS zone from the VNet module
├── keyvault.tf           # the vault + deployer policy + additional policies loop
├── private-endpoint.tf   # optional PE with DNS zone group
├── diagnostics.tf        # optional Log Analytics diagnostic setting
└── outputs.tf            # IDs, URI, PE IP, and a handy App Service reference formatter
```

---

## Usage

### 1. Configure remote state (optional)

Edit `backend.tf` with your own storage account, or pass values at init time:

```bash
terraform init \
  -backend-config="resource_group_name=<your-rg>" \
  -backend-config="storage_account_name=<your-storage-account>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=keyvault.terraform.tfstate"
```

Or comment out the `backend "azurerm"` block to use local state.

### 2. Override defaults

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — at minimum, set a globally unique key_vault_name
```

### 3. Plan and apply

```bash
terraform init
terraform plan
terraform apply
```

---

## Key design choices worth calling out

- **Soft delete + purge protection defaulted on** — purge protection cannot be disabled once enabled, so it's a real commitment. This is intentional: if you're demo-ing the module, flip it off in `tfvars`; for anything real, leave it on.
- **Both auth models supported in one module** — `enable_rbac_authorization` toggles between access policies (default, `false`) and Azure RBAC. When RBAC is on, the access-policy resources collapse to zero via `count`; when it's off, they drive the permission model. No duplication, no separate modules.
- **Deployer gets a policy automatically** — the identity running Terraform is given full secret/key/cert rights via `azurerm_client_config.current.object_id`. Without this, you'd `apply` successfully and then immediately lock yourself out of your own vault.
- **Additional policies via `list(object(...))`** — App Service MSI, OIDC service principals, and teammate object IDs can all be added declaratively after those identities exist, without touching the vault resource itself.
- **Private Endpoint opt-in, wired to the VNet module's outputs** — `data.azurerm_subnet.privateendpoints` and `data.azurerm_private_dns_zone.keyvault` look up resources from the VNet module by convention. This keeps the two modules loosely coupled (no remote state data source needed) while staying explicit about the contract.
- **Diagnostic logging opt-in** — logs cost money, so it's off by default. When you turn it on, you get `AuditEvent` (every data-plane access), `AzurePolicyEvaluationDetails`, and all metrics — enough to answer "who read which secret and when" during an incident.
- **A little quality-of-life output** — `app_service_keyvault_ref_format` emits the exact `@Microsoft.KeyVault(VaultName=...;SecretName=<SECRET-NAME>)` reference string for App Service app settings. Saves a trip to the docs every time.

---

## Outputs

- `key_vault_id`, `key_vault_name`, `key_vault_uri`, `key_vault_tenant_id` — the usual identifiers downstream modules need
- `private_endpoint_ip` — the PE's private IP (or `null` when disabled)
- `app_service_keyvault_ref_format` — ready-to-paste App Service Key Vault reference template

---

## Requirements

- Terraform `>= 1.3`
- `hashicorp/azurerm` `~> 3.0`
- The [01_Azure_Vnet](../01_Azure_Vnet) module deployed first, **if you enable the Private Endpoint** (it provides the `snet-privateendpoints` subnet and `privatelink.vaultcore.azure.net` DNS zone)
- Azure credentials discoverable by the provider (CLI login, service principal env vars, or managed identity)

---

## License

MIT — see [LICENSE](../LICENSE) at the repo root.
