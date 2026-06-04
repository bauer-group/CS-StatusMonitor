# Status Monitor (Uptime Kuma)

Production-ready, self-hosted status & uptime monitoring powered by
[Uptime Kuma](https://github.com/louislam/uptime-kuma) **2**, packaged as a thin
BAUER GROUP edition image with reverse-proxy-friendly defaults and full CI/CD
automation.

Tracks the floating `2` image tag — always the latest Uptime Kuma 2.x, with the
major pinned to avoid a breaking jump to 3.x.

A thin, professional wrapper around the official `louislam/uptime-kuma` image:
no forking, no provisioning sidecar, no secrets. All monitors, notifications,
status pages and the admin account are configured in the web UI and persisted to
a single data volume.

## Features

- **Modern monitoring** — Uptime Kuma 2.x: HTTP(s)/TCP/ping/DNS/push/Docker/DB
  monitors, 90+ notification channels, public & private status pages, a live
  socket.io dashboard.
- **No secrets to manage** — the admin account is created in the first-run setup
  wizard and stored in the data volume; there is nothing in `.env` to rotate or
  leak.
- **Reverse-proxy ready** — sane `UPTIME_KUMA_WS_ORIGIN_CHECK` + iframe defaults
  baked into the image; WebSockets work through Traefik/Coolify with zero extra
  config. See [docs/reverse-proxy.md](docs/reverse-proxy.md).
- **Four deployment modes** — development (local build), single (direct port),
  Traefik (HTTPS + Let's Encrypt), Coolify (dashboard domains).
- **CI/CD automation** — semantic releases, GHCR image builds, base-image
  monitoring, Dependabot auto-merge, SBOMs, Teams + AI issue triage.

## Quick Start

1. **Clone & enter**
   ```bash
   git clone https://github.com/bauer-group/CS-StatusMonitor.git
   cd CS-StatusMonitor
   ```

2. **Create `.env`** (no secrets to generate — just copy the template)
   ```bash
   cp .env.example .env            # Linux/macOS
   Copy-Item .env.example .env     # Windows PowerShell
   ```

3. **Review `.env`** — set `STACK_NAME`, `TIME_ZONE`, and (for Traefik/Coolify)
   `SERVICE_HOSTNAME` / `PROXY_NETWORK`.

4. **Start**
   ```bash
   # Development (local build, direct host port)
   docker compose -f docker-compose.development.yml up -d --build

   # Single (pre-built GHCR image, direct host port)
   docker compose -f docker-compose.single.yml up -d

   # Traefik (HTTPS dashboard via Let's Encrypt)
   docker compose -f docker-compose.traefik.yml up -d
   ```

5. **Set up** — open the dashboard and complete the setup wizard (creates the
   admin account):

   | Mode | URL |
   | --- | --- |
   | Development / Single | `http://localhost:3001` |
   | Traefik / Coolify | `https://${SERVICE_HOSTNAME}` |

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     Docker Compose Stack                       │
│                                                                │
│   ┌────────────────────────────────────────────┐              │
│   │                 uptime-kuma                  │              │
│   │            (BAUER GROUP edition)             │              │
│   │                                              │              │
│   │   HTTP + socket.io   :3001                   │              │
│   │   Healthcheck        extra/healthcheck       │              │
│   │   PID 1              dumb-init               │              │
│   │                                              │              │
│   │   /app/data ──► uptime-kuma-data volume      │              │
│   │   (DB, monitors, notifications, users)       │              │
│   └────────────────────────────────────────────┘              │
│         ▲                                                       │
│         │ HTTPS terminated by Traefik / Coolify (proxy mode)   │
└─────────┼──────────────────────────────────────────────────────┘
          │
      ${SERVICE_HOSTNAME}
```

## Deployment Modes

| Mode | Compose file | UI exposure | Use for |
| --- | --- | --- | --- |
| **Development** | `docker-compose.development.yml` | host port | local builds & testing |
| **Single** | `docker-compose.single.yml` | host port | simple single-host, GHCR image |
| **Traefik** | `docker-compose.traefik.yml` | Traefik + Let's Encrypt | HTTPS dashboard |
| **Coolify** | `docker-compose.coolify.yml` | Coolify dashboard | PaaS-managed domains & TLS |

## Configuration

Everything is driven from `.env` — see [docs/configuration.md](docs/configuration.md)
for the full variable reference. Highlights:

- **Image** — `UPTIME_KUMA_IMAGE` / `…_IMAGE_VERSION` (GHCR pull) or
  `UPTIME_KUMA_REPOSITORY` / `UPTIME_KUMA_VERSION` (local build base).
- **Proxy behaviour** — `UPTIME_KUMA_WS_ORIGIN_CHECK`,
  `UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN`.
- **Networking** — `PORT_HTTP` (dev/single), `SERVICE_HOSTNAME` + `PROXY_NETWORK`
  (Traefik/Coolify).

## Ports

| Port | Purpose |
| --- | --- |
| 3001 | HTTP dashboard / public status pages / socket.io WebSocket |

## Documentation

- [Installation](docs/installation.md)
- [Configuration](docs/configuration.md)
- [Reverse proxy & TLS](docs/reverse-proxy.md)
- [Backup & restore](docs/backup-and-restore.md)
- [Server image reference](src/uptime-kuma/README.md)

## License

MIT License — BAUER GROUP. See [LICENSE](LICENSE).
