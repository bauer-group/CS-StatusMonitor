# Cloudflare — Infrastructure as Code (Terraform / OpenTofu)

Manages the Cloudflare side of the Status Monitor declaratively: **Tunnel, Ingress,
DNS** — and optionally **Cloudflare Access**. The module creates the tunnel and
outputs its **run token**, which feeds `TUNNEL_TOKEN` in the same `cloudflared`
container as the [dashboard/token fallback](../../docs/cloudflare-tunnel.md).

Compatible with Terraform **and** OpenTofu (identical HCL). This project targets
**OpenTofu** — every command below works 1:1 with `terraform` as well.

## What it creates

| Resource | Purpose |
| --- | --- |
| `cloudflare_zero_trust_tunnel_cloudflared` | The tunnel (remote-managed, `config_src = "cloudflare"`) |
| `cloudflare_zero_trust_tunnel_cloudflared_config` | Ingress: `service_hostname` → `http://status-monitor:3001` + catch-all 404 |
| `cloudflare_dns_record` | Proxied `CNAME` `service_hostname` → `<tunnel-id>.cfargotunnel.com` |
| `cloudflare_zero_trust_access_policy` + `_application` | **Optional** (only when `access_enabled = true`) — locks the instance to an email domain |

There are **no zone-wide rulesets** here. Unlike an S3/SigV4 API, Uptime Kuma needs
no WAF / no-transform / cache rules — so this module only ever touches its own
standalone objects and never the shared zone configuration of other stacks.

## Prerequisites

- Cloudflare **API token** with scopes:
  - Account → *Cloudflare Tunnel*: Edit
  - Account → *Access: Apps and Policies*: Edit — **only** if `access_enabled = true`
  - Zone → *DNS*: Edit
- **Account ID** and **Zone ID** (Dashboard → domain Overview → API).

## Usage

```bash
cd infrastructure/cloudflare

# 1. Secret as ENV (not in files)
export TF_VAR_cloudflare_api_token='<token>'

# 2. Set variables
cp terraform.tfvars.example terraform.tfvars   # fill account_id, zone_id, hostname

# 3. Plan & apply
tofu init
tofu plan
tofu apply

# 4. Grab the run token for the container
tofu output -raw tunnel_token
```

> On Terraform, replace `tofu` with `terraform` — same subcommands.
> Install OpenTofu: `winget install OpenTofu.Tofu` (Windows) · `brew install opentofu` (macOS) · <https://opentofu.org/docs/intro/install/> (Linux).

## Bring the token into the stack

Provide the output token as `TUNNEL_TOKEN` — the cloudflared container from
[`docker-compose.cloudflare.yml`](../../docker-compose.cloudflare.yml) reads it:

```bash
TUNNEL_TOKEN="$(tofu output -raw tunnel_token)"
docker compose -f docker-compose.cloudflare.yml up -d
```

> Cloudflare maintains ingress **and** DNS automatically after apply. Changes to
> the hostname/routing go exclusively through `tofu apply` (config-as-code).

## Optional: private status page (Cloudflare Access)

Uptime Kuma serves public status pages and the admin login on the same port, so
Access is **off by default** (the admin area is already behind Uptime Kuma's own
login). Set `access_enabled = true` **only** for a fully-internal status page:

```hcl
access_enabled              = true
access_allowed_email_domain = "de.bauer-group.com"
```

> ⚠️ This gates **every** request — including the public status pages — behind a
> Cloudflare login. Do not enable it if you want the status page to be public.

## State isolation

Use a **dedicated** state for this project (see the backend example in
`versions.tf`). Do not share state with other stacks in the same zone. The
committed `.terraform.lock.hcl` pins the provider version for reproducible runs.

## Operating modes

| Mode | Tunnel / Ingress / DNS | Setup | When |
| --- | --- | --- | --- |
| **IaC (this module)** | Terraform / OpenTofu | `tofu apply` | Primary — everything versioned |
| **Token fallback** | Cloudflare dashboard | Token in `.env` | Quick test / emergency |

Both use the same `docker-compose.cloudflare.yml`; only the source of the
tunnel/routing/DNS and the token differs.

## Files

| File | Content |
| --- | --- |
| `versions.tf` | Provider pin (v5) + state backend (isolated) |
| `variables.tf` | Inputs (hostname, target, Access toggle) |
| `main.tf` | Tunnel, token, ingress, DNS, optional Access |
| `outputs.tf` | `tunnel_id`, `tunnel_cname`, `tunnel_token` |
| `terraform.tfvars.example` | Example variables |
