# =============================================================================
# Terraform / Provider Requirements
# =============================================================================
# Cloudflare Provider v5 (v4 resource names are incompatible).
# Compatible with Terraform AND OpenTofu — identical HCL, same state, same lock.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.8.2, < 6.0.0"
    }
  }

  # ── State backend (IMPORTANT for multi-stack isolation) ───────────────────
  # This project should use its OWN dedicated state. Do NOT share the state with
  # other stacks in the same Cloudflare zone — otherwise the tool would know
  # their resources and could touch them on destroy/apply.
  #
  # Without a backend block the state lives locally (fine for first tests; it is
  # gitignored). Uncomment and adapt ONE of the examples below for real use.
  #
  # S3-compatible backend (AWS S3, MinIO, ...):
  # backend "s3" {
  #   bucket                      = "tfstate-example"
  #   key                         = "status-monitor/cloudflare.tfstate"
  #   region                      = "eu-central-1"
  #   endpoints                   = { s3 = "https://s3.example.com" }
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  #   skip_requesting_account_id  = true
  #   use_path_style              = true
  # }
  #
  # Alternatives: HCP Terraform / Terraform Cloud (cloud {}), GitLab HTTP backend.
}

provider "cloudflare" {
  # API token only via ENV/tfvars — never hardcode.
  # Scopes: Account -> Cloudflare Tunnel:Edit (+ Access: Apps and Policies:Edit
  #         only when access_enabled=true); Zone -> DNS:Edit.
  api_token = var.cloudflare_api_token
}
