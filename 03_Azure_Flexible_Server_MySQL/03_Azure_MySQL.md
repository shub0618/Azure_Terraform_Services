# 03_Azure_MySQL

A reference Terraform module for provisioning an **Azure Database for MySQL Flexible Server** with VNet integration, Private DNS resolution, hardened server parameters, and a ready-to-use application database.

> Module 3 of the [Azure_Terraform_Services](../README.md) series. Consumes outputs from [01_Azure_Vnet](../01_Azure_Vnet) via `terraform_remote_state` — the VNet module must be deployed first. Designed to sit behind an App Service that talks to it over the private `snet-mysql` subnet.

---

## What this creates

| Resource | Purpose |
|---|---|
| MySQL Flexible Server | Private-only by default (VNet-delegated), with hardened defaults |
| Application database | `appdb` with `utf8mb4` charset, ready for app workloads |
| Server parameters × 7 | TLS 1.2/1.3 only, require_secure_transport, slow query log, audit logging, bumped connection ceiling |

---

## File layout

```
.
├── provider.tf                  # azurerm provider + version pins
├── backend.tf                   # remote state on Azure Storage (edit before init)
├── data.tf                      # reads VNet module's outputs via terraform_remote_state
├── vars.tf                      # all inputs with validations and sensible defaults
├── mysql.tf                     # server + database + 7 server parameter resources
├── outputs.tf                   # IDs, FQDN, admin username, connection string template
└── terraform.tfvars.example     # sample tfvars you copy to terraform.tfvars
```

---

## Usage

### 1. Configure remote state

Edit `backend.tf` **and** the `terraform_remote_state` block inside `data.tf` with the same storage account you used for the VNet module. Both files reference the storage account by name.

Or pass via `-backend-config` at init time (note: this only affects `backend.tf` — the `data.tf` reference to the VNet's state still needs editing):

```bash
terraform init \
  -backend-config="resource_group_name=<your-rg>" \
  -backend-config="storage_account_name=<your-storage-account>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=mysql.terraform.tfstate"
```

### 2. Set the admin password via environment variable

**Never put the password in `terraform.tfvars`.** Pass it through the environment:

```bash
export TF_VAR_mysql_admin_password='YourStr0ng!Pass#here'
```

### 3. Override other defaults

```bash
cp terraform.tfvars.example terraform.tfvars
# edit mysql_server_name to be globally unique
```

### 4. Plan and apply

```bash
terraform init
terraform plan
terraform apply
```

Provisioning a MySQL Flexible Server typically takes 5–10 minutes.

---

## Key design choices worth calling out

- **VNet-integrated, no public endpoint** — the server lives in the delegated `snet-mysql` subnet. Applications in the VNet (App Service via VNet integration, VMs, etc.) reach it through the Private DNS zone created by the VNet module. There is no public IP.
- **TLS 1.2+ enforced, secure transport required** — two server parameters set at boot: `require_secure_transport = ON` and `tls_version = TLSv1.2,TLSv1.3`. Connections over plaintext or older TLS fail at the handshake.
- **Audit logging on by default** — `audit_log_enabled = ON` with `CONNECTION,DCL,DDL` events. Captures logins, permission changes, and schema changes, but skips high-volume `DML` to keep logs manageable. Turn on DML explicitly if you need it.
- **`slow_query_log = ON`, threshold 2 seconds** — queries taking longer than 2s get logged. Useful for finding N+1 patterns early.
- **`max_connections = 120`** — tuned for 8 autoscaling instances × 10 connections each, plus 40 headroom for admin, monitoring, and Cloud Shell sessions. Bump this if you scale wider.
- **Password in `ignore_changes`** — `administrator_password` is in the `lifecycle { ignore_changes }` block. Rotate via Azure CLI or the portal without Terraform fighting you on the next apply.
- **Admin username validation** — reserved names (`admin`, `root`, `sa`, `azure_superuser`, etc.) are blocked via variable validation. Azure rejects these anyway, but catching it at `terraform plan` time gives a much better error message.
- **`terraform_remote_state` instead of data-source lookup** — this module consumes *several* outputs from the VNet module in one shot (RG, subnet ID, DNS zone ID from a map). The remote-state approach is cleaner here than wiring up five separate `data "azurerm_*"` blocks. [The Key Vault module](../02_Azure_KeyVaults) took the other path — both are valid; pick based on how much state you're reading.

---

## Outputs

- `mysql_server_id`, `mysql_server_name`, `mysql_server_fqdn` — identifiers for downstream modules
- `mysql_database_name`, `mysql_admin_username` — for building connection strings in the app
- `mysql_connection_string` — pre-formatted `mysql://` URI template with `<PASSWORD>` placeholder (compatible with `mysql2`, `PyMySQL`, and most drivers); marked `sensitive` so it doesn't leak in plan output

---

## Cost notes

MySQL Flexible Server is the biggest line item in this stack. Rough estimates at the time of writing:

| SKU | Specs | Monthly |
|---|---|---|
| `B_Standard_B1ms` | 1 vCore, 2 GB RAM | ~$16 |
| `B_Standard_B2s` | 2 vCores, 4 GB RAM | ~$32 |
| `GP_Standard_D2ds_v4` | 2 vCores, 8 GB RAM | ~$140 |

Plus storage (~$0.12/GB/month) and backups. **Run `terraform destroy` when you're done demoing** — this is not a resource you want to leave running by accident.

---

## Requirements

- Terraform `>= 1.3`
- `hashicorp/azurerm` `~> 3.0`
- The [01_Azure_Vnet](../01_Azure_Vnet) module deployed, with its remote state accessible
- Azure credentials discoverable by the provider

---

## License

MIT — see [LICENSE](../LICENSE) at the repo root.
