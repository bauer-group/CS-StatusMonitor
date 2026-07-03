# =============================================================================
# Cloudflare Tunnel + Ingress + DNS + (optional) Access  (config-as-code)
# =============================================================================
# Only STANDALONE object resources — each managed by its own ID. Terraform/
# OpenTofu touches ONLY the objects declared here; other stacks in the same zone
# stay untouched. There are no zone-wide singleton rulesets in this module
# (unlike an S3 API, Uptime Kuma needs no WAF/no-transform/cache rules).

locals {
  # Derive the DNS record label from the FQDN (status.example.com -> status).
  record_name = trimsuffix(var.service_hostname, ".${var.cloudflare_zone}")

  tunnel_cname = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
}

# ── Tunnel (remote-managed: config_src = "cloudflare") ───────────────────────
resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  config_src = "cloudflare"
}

# ── Run token (passed as TUNNEL_TOKEN into the cloudflared container) ─────────
data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

# ── Ingress routing ──────────────────────────────────────────────────────────
# Single public hostname -> the status-monitor container. The socket.io
# WebSocket rides the same hostname; cloudflared upgrades it transparently.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = [
      {
        hostname = var.service_hostname
        service  = var.service_url
        origin_request = {
          # Forward the public hostname as Host so Uptime Kuma's cors-like
          # WebSocket Origin check passes.
          http_host_header = var.service_hostname
        }
      },
      {
        # Catch-all (required as the last rule).
        service = "http_status:404"
      },
    ]
  }
}

# ── DNS: proxied CNAME onto the tunnel ───────────────────────────────────────
resource "cloudflare_dns_record" "status" {
  zone_id = var.cloudflare_zone_id
  name    = local.record_name
  type    = "CNAME"
  content = local.tunnel_cname
  proxied = true
  ttl     = 1
}

# ── Cloudflare Access (optional — only when access_enabled = true) ───────────
# Policy (reusable, account-scoped): allow a single email domain.
resource "cloudflare_zero_trust_access_policy" "admins" {
  count = var.access_enabled ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = "${var.tunnel_name} — Allowed"
  decision   = "allow"

  include = [
    {
      email_domain = {
        domain = var.access_allowed_email_domain
      }
    },
  ]
}

# Application: gate the public hostname. account-scoped — Cloudflare resolves the
# domain to the correct zone automatically.
resource "cloudflare_zero_trust_access_application" "status" {
  count = var.access_enabled ? 1 : 0

  account_id       = var.cloudflare_account_id
  name             = var.tunnel_name
  domain           = var.service_hostname
  type             = "self_hosted"
  session_duration = var.access_session_duration

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.admins[0].id
      precedence = 1
    },
  ]
}
