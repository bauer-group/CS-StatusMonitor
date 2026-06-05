# Installation

## Prerequisites

- Docker Engine 24+ with the Compose v2 plugin (`docker compose`)
- For Traefik mode: a running Traefik instance on the external `${PROXY_NETWORK}`
  network and a DNS record for `${SERVICE_HOSTNAME}` pointing at this host
- For Coolify mode: a Coolify instance (it provides the proxy + TLS)

## 1. Configure environment

There are **no secrets to generate** — the admin account is created in the web
setup wizard on first start. Just copy the example and review it:

```bash
cp .env.example .env            # Linux/macOS
Copy-Item .env.example .env     # Windows PowerShell
```

Edit `.env`:

- `STACK_NAME` — name prefix for the container, volume and network
- `TIME_ZONE` — e.g. `Europe/Berlin`
- For Traefik/Coolify: `SERVICE_HOSTNAME`, and for Traefik `PROXY_NETWORK`
- Optional app knobs: `UPTIME_KUMA_WS_ORIGIN_CHECK`,
  `UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN`, `UPTIME_KUMA_HOST`
  (see [configuration.md](configuration.md))

## 2. Start

```bash
# Development — local image build, direct host port
docker compose -f docker-compose.development.yml up -d --build

# Single — pre-built GHCR image, direct host port
docker compose -f docker-compose.single.yml up -d

# Traefik — HTTPS dashboard via Let's Encrypt
docker compose -f docker-compose.traefik.yml up -d
```

For **Coolify**, import `docker-compose.coolify.yml` in the dashboard, set the
service Domain to `https://${SERVICE_HOSTNAME}` on port `3001`, and deploy.

## 3. First-run setup

Open the dashboard and complete the one-time setup wizard:

| Mode | URL |
| --- | --- |
| Development / Single | `http://localhost:3001` |
| Traefik / Coolify | `https://${SERVICE_HOSTNAME}` |

The wizard creates the **administrator account** and writes it (with all future
monitors, notifications and status pages) to the `status-monitor-data` volume.
There is no admin password in `.env` by design.

## 4. Verify

```bash
# Container healthy? (look for "healthy" in STATUS)
docker compose -f docker-compose.development.yml ps

# Boot banner + effective config
docker compose -f docker-compose.development.yml logs status-monitor | head -n 30

# Dashboard reachable?
curl -fsS http://localhost:3001 >/dev/null && echo OK
```

## Upgrading Uptime Kuma

The data volume persists across restarts, so upgrades are non-destructive:

```bash
# GHCR (single/traefik/coolify): bump STATUS_MONITOR_IMAGE_VERSION in .env, then
docker compose -f docker-compose.single.yml pull
docker compose -f docker-compose.single.yml up -d

# Development (local build): bump UPTIME_KUMA_VERSION in .env, then
docker compose -f docker-compose.development.yml up -d --build
```

> **Back up first.** Uptime Kuma 2.x performs an automatic, one-way database
> migration on first boot of a new major. Snapshot the data volume before a
> major jump — see [backup-and-restore.md](backup-and-restore.md). Review the
> upstream [release notes](https://github.com/louislam/uptime-kuma/releases)
> before crossing major versions.

Base-image digest moves are picked up automatically by `check-base-images.yml`
(daily) and tag bumps by Dependabot, both of which trigger a fresh GHCR build.
