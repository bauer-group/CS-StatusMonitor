# Cloudflare Tunnel

Expose the status page through an outbound **Cloudflare Tunnel** — no open ports,
no origin certificate, no inbound firewall rules. `cloudflared` runs as a sidecar
in `docker-compose.cloudflare.yml` and dials out to Cloudflare; the status page is
bound to the tunnel only over the internal `local` Docker network.

This is the fifth deployment mode, alongside development / single / Traefik / Coolify.

## How it works

```
              ┌─────────────────── Docker Compose stack ───────────────────┐
              │                                                             │
  Browser     │   ┌───────────────────┐        ┌─────────────────────┐     │
  HTTPS ──►  Cloudflare edge  ◄══ QUIC ══   cloudflare-tunnel        │     │
  (TLS at edge)                    (outbound) │  (cloudflared)        │     │
              │                               └──────────┬──────────┘     │
              │                                          │ http://          │
              │                               ┌──────────▼──────────┐      │
              │                               │   status-monitor     │      │
              │                               │   :3001 (HTTP + WS)  │      │
              │                               └─────────────────────┘      │
              │            no `ports:` — nothing published to the host      │
              └─────────────────────────────────────────────────────────────┘
```

- **TLS terminates at the Cloudflare edge** (Universal SSL). The origin serves plain
  HTTP, so there is no Let's Encrypt / cert-resolver step (unlike Traefik mode).
- **WebSocket** (socket.io, same port `3001`) is proxied transparently by
  cloudflared over the same hostname — Cloudflare WebSocket support is on by default,
  no extra configuration required.
- **Ingress + DNS** live on the Cloudflare side (IaC or dashboard), not in the
  compose file. In token mode cloudflared always fetches its ingress remotely.

## Prerequisites

- A domain on Cloudflare (the public hostname `SERVICE_HOSTNAME` lives in that zone).
- Docker Engine 24+ with Compose v2.
- Either OpenTofu/Terraform (recommended path) **or** access to the Cloudflare
  Zero Trust dashboard (fallback path).

---

## Path A — OpenTofu / Terraform (recommended)

Provisions the tunnel, ingress, proxied DNS record and (optionally) Cloudflare
Access as code, and emits the run token. See
[`infrastructure/cloudflare/`](../infrastructure/cloudflare/) for the module.

```bash
cd infrastructure/cloudflare

# 1. API token as ENV (scopes: Account -> Cloudflare Tunnel:Edit; Zone -> DNS:Edit;
#    + Account -> Access: Apps and Policies:Edit only if you set access_enabled=true)
export TF_VAR_cloudflare_api_token='<token>'

# 2. Variables
cp terraform.tfvars.example terraform.tfvars   # fill account_id, zone_id, zone, hostname

# 3. Plan & apply
tofu init
tofu plan          # expect ONLY "will be created"
tofu apply

# 4. Run token -> the container
cd ../..
TUNNEL_TOKEN="$(tofu -chdir=infrastructure/cloudflare output -raw tunnel_token)"

# 5. Start the stack
export TUNNEL_TOKEN
docker compose -f docker-compose.cloudflare.yml up -d
```

In production, store the token as a secret ENV in your deployment platform (Coolify,
CI, etc.) rather than exporting it in a shell.

---

## Path B — Dashboard / token (fallback)

For a quick test or when you cannot run OpenTofu.

1. **Create the tunnel.** Cloudflare Dashboard → **Zero Trust → Networks → Tunnels
   → Create a tunnel → Cloudflared**. Name it e.g. `status-monitor`. Cloudflare
   shows an install command containing a token — copy only the `eyJ…` token.

2. **Set the token** in `.env`:

   ```env
   TUNNEL_TOKEN=eyJ...
   ```

3. **Add a Public Hostname** on the tunnel (**Public Hostname → Add a public
   hostname**). This also auto-creates the proxied DNS `CNAME`:

   | Field | Value |
   | --- | --- |
   | Subdomain | `status` (whatever matches `SERVICE_HOSTNAME`) |
   | Domain | your zone, e.g. `example.domain.com` |
   | Service — Type | `HTTP` |
   | Service — URL | `status-monitor:3001` |

4. **Start the stack:**

   ```bash
   docker compose -f docker-compose.cloudflare.yml up -d
   ```

Both paths use the same compose file; only the source of the tunnel/ingress/DNS
and the token differs.

---

## WebSocket / live dashboard

Keep `UPTIME_KUMA_WS_ORIGIN_CHECK=cors-like` (the default). cloudflared forwards the
public hostname as the `Host` header, so Uptime Kuma's Origin check passes and the
live dashboard stays connected.

If the dashboard loads but shows **"Disconnected"** / keeps reconnecting behind the
tunnel, fall back to bypassing the check (mirrors [reverse-proxy.md](reverse-proxy.md)):

```env
UPTIME_KUMA_WS_ORIGIN_CHECK=bypass
```

## Optional: private status page (Cloudflare Access)

By default the status page is **public** (the admin area is protected by Uptime
Kuma's own login). To lock the **whole** instance to a company email domain — a
fully-internal status page — enable Cloudflare Access:

- **IaC:** set `access_enabled = true` (+ `access_allowed_email_domain`) in
  `terraform.tfvars`, then `tofu apply`.
- **Dashboard:** Zero Trust → **Access → Applications → Add → Self-hosted**, domain
  `SERVICE_HOSTNAME`, with an *Allow* policy for your email domain.

> ⚠️ Access gates **every** request, including the **public status pages** — every
> visitor hits a Cloudflare login. Only use this for an internal-only status page.

## Verification

```bash
# Tunnel connected? (look for "Registered tunnel connection")
docker logs ${STACK_NAME:-status-monitor}_TUNNEL

# Edge reachable? (200 or 302 from Uptime Kuma)
curl -I https://status.example.domain.com
```

Then open `https://SERVICE_HOSTNAME`, complete the first-run setup wizard, and
confirm the live dashboard is connected (not "Disconnected").

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `502`/`error 1033` at the edge | cloudflared started before the app was healthy, or wrong `service` URL. It must be `http://status-monitor:3001`; the tunnel `depends_on` the app healthcheck. |
| Dashboard shows **Disconnected** | WebSocket Origin check. Set `UPTIME_KUMA_WS_ORIGIN_CHECK=bypass` and restart. |
| `404` for the hostname | Public Hostname / ingress not configured, or request fell through to the catch-all. Re-check the hostname mapping. |
| Public status page asks for a Cloudflare login | Cloudflare Access is enabled on the hostname. Disable it (or `access_enabled = false`) for a public status page. |
| Tunnel container keeps restarting | Invalid or empty `TUNNEL_TOKEN`. Re-copy the token / re-read `tofu output -raw tunnel_token`. |
| DNS not resolving | The `CNAME` must be **proxied** (orange cloud) → `<tunnel-id>.cfargotunnel.com`. IaC sets `proxied = true`; the dashboard Public Hostname flow sets it automatically. |
