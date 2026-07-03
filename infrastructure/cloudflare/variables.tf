# =============================================================================
# Variables
# =============================================================================

# ── Cloudflare access ────────────────────────────────────────────────────────
variable "cloudflare_api_token" {
  description = "Cloudflare API token (scoped). Supply via ENV TF_VAR_cloudflare_api_token or tfvars — never hardcode."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (the tunnel and Access are account-scoped)."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Zone ID of the domain that hosts service_hostname (used for the DNS record)."
  type        = string
}

variable "cloudflare_zone" {
  description = "Zone name (apex domain), e.g. example.domain.com. Used to derive the DNS record label from service_hostname."
  type        = string
  default     = "example.domain.com"
}

# ── Tunnel ───────────────────────────────────────────────────────────────────
variable "tunnel_name" {
  description = "Display name of the tunnel in the Cloudflare dashboard."
  type        = string
  default     = "status-monitor"
}

# ── Public hostname + internal target ────────────────────────────────────────
variable "service_hostname" {
  description = "Public hostname of the status page / dashboard (must be inside cloudflare_zone)."
  type        = string
  default     = "status.example.domain.com"
}

variable "service_url" {
  description = "Internal tunnel target — the status-monitor container on the Docker 'local' network."
  type        = string
  default     = "http://status-monitor:3001"
}

# ── Cloudflare Access (optional — private status page) ───────────────────────
# Uptime Kuma serves PUBLIC status pages and the admin login on the same port.
# Leave access_enabled = false (default) for a normal public status page: the
# admin area is already protected by Uptime Kuma's own login. Set it to true ONLY
# for a fully-internal status page — Access then gates EVERY request (including
# the public status pages) behind a Cloudflare login for the allowed email domain.
variable "access_enabled" {
  description = "Protect the whole instance with Cloudflare Access (private status page). WARNING: this also gates the public status pages behind a Cloudflare login."
  type        = bool
  default     = false
}

variable "access_allowed_email_domain" {
  description = "Email domain allowed through Cloudflare Access (only used when access_enabled = true)."
  type        = string
  default     = "de.bauer-group.com"
}

variable "access_session_duration" {
  description = "Cloudflare Access session lifetime (only used when access_enabled = true)."
  type        = string
  default     = "24h"
}
