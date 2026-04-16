# 04_Azure_AppService

A reference Terraform module for provisioning an **Azure Linux App Service** with VNet integration, a system-assigned Managed Identity that reads secrets from Key Vault, CPU/memory-based autoscaling, health checks, and optional diagnostic logging.

> Module 4 of the [Azure_Terraform_Services](../README.md) series — the one that actually runs your code. Consumes remote state from all three upstream modules: [01_Azure_Vnet](../01_Azure_Vnet) (subnet for VNet integration), [02_Azure_KeyVaults](../02_Azure_KeyVaults) (for secret references), and [03_Azure_MySQL](../03_Azure_MySQL) (where this app talks to the database).

---

## What this creates

| Resource | Purpose |
|---|---|
| App Service Plan | S1 Standard by default — the smallest tier that supports both VNet integration and autoscale |
| Linux Web App | Node.js 20 LTS, HTTPS-only, TLS 1.2+, FTPS disabled, ARR Affinity off |
| System-assigned Managed Identity | For passwordless Key Vault access at runtime |
| Key Vault access policy | Grants the MI `Get` on secrets — least privilege |
| Autoscale setting *(optional, default on)* | Scale out on CPU > 70% or memory > 80%; scale in on CPU < 30%; min 2 / max 8 |
| Custom hostname binding *(optional)* | Only created when `var.custom_domain` is non-empty |
| Diagnostic Setting *(optional)* | HTTP logs, console logs, app logs, and all metrics → Log Analytics |

---

## File layout

```
.
├── provider.tf                  # azurerm provider + version pins
├── backend.tf                   # remote state on Azure Storage (edit before init)
├── data.tf                      # reads 3 upstream modules' state via terraform_remote_state
├── vars.tf                      # all inputs with validations and sensible defaults
├── appservice.tf                # Service Plan + Web App (Managed Identity, VNet, KV refs)
├── autoscale.tf                 # CPU + memory scale rules (3 rules total)
├── keyvault-access.tf           # Access policy granting MI 'Get' on secrets
├── diagnostics.tf               # Optional Log Analytics diagnostic setting
├── outputs.tf                   # App URL, hostname, MI principal ID, outbound IPs
└── terraform.tfvars.example     # Sample tfvars to copy and customize
```

---

## Usage

### 1. Configure remote state

Edit `backend.tf` and **all three `terraform_remote_state` blocks in `data.tf`** with the same storage account you used for the upstream modules. Four places total to update the storage account name.

### 2. Seed the Key Vault with app secrets

Before this module's first successful startup, the Key Vault needs to contain the secrets the app settings reference. Using Azure CLI:

```bash
az keyvault secret set --vault-name <your-vault> --name DB-HOST       --value "<mysql-fqdn>"
az keyvault secret set --vault-name <your-vault> --name DB-USER       --value "<admin-user>"
az keyvault secret set --vault-name <your-vault> --name DB-PASSWORD   --value "<password>"
az keyvault secret set --vault-name <your-vault> --name DB-NAME       --value "<database>"
az keyvault secret set --vault-name <your-vault> --name JWT-SECRET    --value "<random-32-bytes>"
az keyvault secret set --vault-name <your-vault> --name JWT-EXPIRES-IN --value "24h"
```

The DB values can come directly from the MySQL module's outputs (`terraform output` in `03_Azure_MySQL/`).

### 3. Override defaults

```bash
cp terraform.tfvars.example terraform.tfvars
# edit web_app_name to be globally unique
```

### 4. Plan and apply

```bash
terraform init
terraform plan
terraform apply
```

### 5. Deploy your code

This module provisions the infrastructure; deploying the Node.js application itself is a separate step (zip deploy, GitHub Actions, Azure DevOps, etc.). Point your deployment pipeline at the `app_service_name` output.

---

## Key design choices worth calling out

- **S1 Standard is the floor** — not the cheapest option. B-series is cheaper but doesn't support autoscale, and F1/D1 don't support VNet integration. Choosing S1 here reflects a real trade-off: paying ~$70/month for the ability to scale and keep traffic private, rather than ~$13/month for a non-scalable public-facing app.
- **Managed Identity, not service principal credentials** — the Web App gets a system-assigned MI that Key Vault trusts via the access policy created in `keyvault-access.tf`. No secrets need to flow from CI/CD to the app. The `@Microsoft.KeyVault(...)` reference syntax in `app_settings` resolves at runtime using the MI's token.
- **`Get` only, no `List`** — the access policy grants the MI exactly one permission: `Get`. It can read secrets whose names it knows, but it can't enumerate the vault. This is the right default for a runtime consumer.
- **VNet integration via `virtual_network_subnet_id`** — the app's outbound traffic routes through `snet-appservice`, so MySQL and Key Vault see it come from inside the VNet. This is what makes the whole "private-only" story hold together.
- **Always-on + health check + 5-minute eviction** — `always_on = true` prevents Azure from idling the app (which breaks background jobs and kills the first request after idle). The health check hits `/api/health` every minute; instances that fail for 5 minutes get evicted from the load balancer.
- **`lifecycle { ignore_changes }` on App Insights settings** — the two App Insights env vars are in `ignore_changes` because they're typically added by the App Insights resource (or by ops via portal) after this module runs. Without this, every `terraform apply` would fight the portal change.
- **Autoscale rules are asymmetric by design** — scale-out is aggressive (CPU > 70% for 10 min, memory > 80% for 10 min; +1 instance with 5-min cooldown). Scale-in is conservative (CPU < 30% for 15 min; -1 instance with 10-min cooldown). This avoids thrashing during spiky traffic — scaling down too fast is worse than running a few extra instances for another 10 minutes.
- **Custom domain is opt-in, not forced** — the `azurerm_app_service_custom_hostname_binding` resource has `count = var.custom_domain != "" ? 1 : 0`. Deploy first, wire DNS, add the domain to tfvars, apply again. Trying to bind a hostname before DNS points at the app would fail.
- **`try()` fallback for Key Vault name** — `data.tf` uses `try(data.terraform_remote_state.keyvault.outputs.key_vault_name, var.key_vault_name)`. This lets the module apply even when the Key Vault module's state isn't reachable (useful for testing), falling back to the explicit variable. Belt-and-braces for a module with three upstream dependencies.

---

## App settings and secret references

The `app_settings` block in `appservice.tf` uses Azure's built-in Key Vault reference syntax:

```
"DB_PASSWORD" = "@Microsoft.KeyVault(VaultName=<vault>;SecretName=DB-PASSWORD)"
```

At startup, the App Service substitutes these with the actual secret values (fetched via the Managed Identity's token). The app code reads them as plain environment variables — it never sees a Key Vault URL or needs the Azure SDK for secrets.

Required secret names in the vault (dashes, not underscores — Key Vault doesn't allow underscores in secret names):
`DB-HOST`, `DB-USER`, `DB-PASSWORD`, `DB-NAME`, `JWT-SECRET`, `JWT-EXPIRES-IN`

---

## Outputs

- `app_service_id`, `app_service_name`, `app_service_plan_id` — identifiers
- `app_service_default_hostname`, `app_service_url` — reachable URLs
- `managed_identity_principal_id`, `managed_identity_tenant_id` — for granting access to other resources (Storage, Service Bus, etc.)
- `outbound_ip_addresses` — useful when a third-party API needs your app's egress IPs whitelisted (though if you enabled the VNet module's NAT Gateway, prefer that static IP instead)

---

## Cost notes

Rough monthly estimates at the time of writing:

| SKU | Specs | Monthly |
|---|---|---|
| `B1` | 1 vCore, 1.75 GB RAM | ~$13 — no autoscale |
| `S1` | 1 vCore, 1.75 GB RAM | ~$70 — default, autoscale + VNet |
| `P1v3` | 2 vCores, 8 GB RAM | ~$122 — prod workloads |

**With autoscale on, you pay per instance-hour.** Min 2 instances × S1 ≈ $140/month baseline. Burst to 8 instances during load spikes adds ~$35/day at full scale. Run `terraform destroy` when demoing.

---

## Requirements

- Terraform `>= 1.3`
- `hashicorp/azurerm` `~> 3.0`
- Upstream modules deployed with state accessible:
  - [`01_Azure_Vnet`](../01_Azure_Vnet) — required (VNet integration)
  - [`02_Azure_KeyVaults`](../02_Azure_KeyVaults) — strongly recommended (app settings reference it); `try()` fallback provided
  - [`03_Azure_MySQL`](../03_Azure_MySQL) — optional for this module to apply, but required for your app to actually work
- Azure credentials discoverable by the provider

---

## License

MIT — see [LICENSE](../LICENSE) at the repo root.
