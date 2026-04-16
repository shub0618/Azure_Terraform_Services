# terraform-azure-vnet

A reference Terraform module for provisioning a **production-shaped Azure Virtual Network** with delegated subnets, NSGs, a route table, an optional NAT Gateway, and Private DNS zones wired for Private Endpoints.

> This is a **personal reference / showcase** repository. It's written as the first layer of a larger private-networking setup (App Service + MySQL Flexible Server + Key Vault + Blob Storage behind Private Endpoints), but it stands on its own — you can `terraform apply` just this and get a clean, well-segmented VNet.

---

## What this creates

| Resource | Purpose |
|---|---|
| Resource Group *(optional)* | Created fresh, or references an existing one via data source |
| Virtual Network | `10.0.0.0/24` by default |
| Subnet: `snet-appservice` | `/26`, delegated to `Microsoft.Web/serverFarms` |
| Subnet: `snet-mysql` | `/26`, delegated to `Microsoft.DBforMySQL/flexibleServers` |
| Subnet: `snet-privateendpoints` | `/27`, network policies disabled for PE support |
| 3 × Network Security Groups | Per-subnet NSGs with least-privilege inbound rules + explicit `DenyAll` at priority 4096 |
| Route Table | Default `0.0.0.0/0 → Internet` route, associated to all three subnets |
| NAT Gateway *(optional)* | Static outbound public IP — useful when you need to whitelist your app's egress IP with third parties |
| 3 × Private DNS zones | `privatelink.mysql.database.azure.com`, `privatelink.blob.core.windows.net`, `privatelink.vaultcore.azure.net` — each linked to the VNet |

### Address plan

```
VNet:  10.0.0.0/24
├── 10.0.0.0/26    (64 IPs)  →  snet-appservice
├── 10.0.0.64/26   (64 IPs)  →  snet-mysql
└── 10.0.0.128/27  (32 IPs)  →  snet-privateendpoints
```

---

## File layout

```
.
├── provider.tf      # azurerm provider + version pins
├── backend.tf       # remote state on Azure Storage (placeholders — edit before init)
├── vars.tf          # all input variables with sensible defaults
├── vnet.tf          # resource group, VNet, 3 subnets
├── nsg.tf           # 3 NSGs and their subnet associations
├── route-table.tf   # route table + 3 associations
├── nat-gateway.tf   # optional NAT gateway (gated behind var.enable_nat_gateway)
├── dns.tf           # Private DNS zones + VNet links (for_each)
└── outputs.tf       # IDs + names exported for consumption by downstream modules
```

---

## Usage

### 1. Configure remote state (optional but recommended)

Edit `backend.tf` with your own Storage Account, or pass the values at init time:

```bash
terraform init \
  -backend-config="resource_group_name=<your-rg>" \
  -backend-config="storage_account_name=<your-storage-account>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=vnet.terraform.tfstate"
```

Or comment out the `backend "azurerm"` block in `backend.tf` to use local state while experimenting.

### 2. Override defaults (optional)

Copy the example and tweak:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your own RG name, region, CIDRs, etc.

### 3. Plan and apply

```bash
terraform init
terraform plan
terraform apply
```

---

## Key design choices worth calling out

- **Delegated subnets** — App Service and MySQL Flexible Server both require subnet delegation. Getting this wrong is one of the most common first-time mistakes; it's baked in here.
- **Explicit `DenyAll_Inbound` at priority 4096** — Azure has an implicit deny, but declaring it explicitly makes audits easier and the intent obvious in code review.
- **MySQL NSG only accepts from the App Service subnet CIDR** — not from `VirtualNetwork`. Tighter blast radius.
- **Private DNS zones are managed via `for_each`** — adding a new service (e.g. Service Bus, Cosmos) is a one-line change in `vars.tf`.
- **NAT Gateway is opt-in** — it's billed per-hour + per-GB, so it's off by default. Flip `enable_nat_gateway = true` only when you actually need a stable outbound IP.
- **RG can be created OR referenced** — `use_existing_resource_group` toggles between a `resource` and a `data` block, so this module slots cleanly into either greenfield or existing-subscription scenarios.

---

## Outputs

All the IDs and names a downstream module (App Service, MySQL, Key Vault, etc.) would typically need — subnet IDs, NSG IDs, DNS zone IDs, and the NAT Gateway public IP when enabled. See `outputs.tf`.

---

## Requirements

- Terraform `>= 1.3`
- `hashicorp/azurerm` `~> 3.0`
- An Azure subscription and credentials discoverable by the provider (Azure CLI login, service principal env vars, or managed identity)

---

## License

MIT — see [LICENSE](./LICENSE).
