# =============================================================================
# Outputs
# =============================================================================

output "tunnel_id" {
  description = "ID of the Cloudflare Tunnel."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_cname" {
  description = "CNAME target of the tunnel (<id>.cfargotunnel.com)."
  value       = local.tunnel_cname
}

# This token feeds TUNNEL_TOKEN in the cloudflared container
# (docker-compose.cloudflare.yml). Read it with:  tofu output -raw tunnel_token
output "tunnel_token" {
  description = "Tunnel run token -> set as ENV TUNNEL_TOKEN in the container."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  sensitive   = true
}
