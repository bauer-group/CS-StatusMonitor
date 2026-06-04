# Configuration

Everything in this stack is driven from `.env`. Uptime Kuma itself stores its
runtime configuration (monitors, notifications, status pages, users) in its
database inside the data volume — **not** in environment variables.

## Environment variables

| Variable | Default | Used by | Purpose |
| --- | --- | --- | --- |
| `STACK_NAME` | `status_example_domain_com` | all | prefix for container/volume/network names |
| `TIME_ZONE` | `Etc/UTC` | all | container timezone (`TZ`) |
| `UPTIME_KUMA_IMAGE` | `ghcr.io/bauer-group/cs-statusmonitor/uptime-kuma` | single/traefik/coolify | published image to pull |
| `UPTIME_KUMA_IMAGE_VERSION` | `latest` | single/traefik/coolify | published image tag |
| `UPTIME_KUMA_REPOSITORY` | `louislam/uptime-kuma` | development | upstream base image to build from |
| `UPTIME_KUMA_VERSION` | `2` | development | upstream base tag (floating 2.x) |
| `UPTIME_KUMA_HOST` | `::` | all | bind address inside the container |
| `UPTIME_KUMA_WS_ORIGIN_CHECK` | `cors-like` | all | WebSocket Origin verification |
| `UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN` | `false` | all | allow embedding status pages in an iframe |
| `PORT_HTTP` | `3001` | development/single | host port mapped to container `3001` |
| `SERVICE_HOSTNAME` | `status.example.domain.com` | traefik/coolify | public hostname |
| `PROXY_NETWORK` | `EDGEPROXY` | traefik | external Traefik network name |

## First-run setup wizard

On the very first start, the dashboard shows a setup screen. This is where the
**admin account** is created. Because the account lives in the database (the
data volume), there is intentionally no admin password in `.env` — which also
means there is nothing to rotate in the environment and no secret to leak.

If you ever need to reset a forgotten admin password, Uptime Kuma supports it
from the host:

```bash
docker compose -f docker-compose.single.yml exec uptime-kuma \
  node extra/reset-password.js
```

## Bind address (`UPTIME_KUMA_HOST`)

The upstream default `::` binds dual-stack (IPv6 + IPv4-mapped) and works on the
IPv6-enabled `local` network used by the development/single modes. If your host
has IPv6 disabled and the container fails to bind, set:

```env
UPTIME_KUMA_HOST=0.0.0.0
```

## Internal port is fixed at 3001

`PORT_HTTP` changes only the **host** side of the mapping (`PORT_HTTP:3001`).
The container always listens on `3001`, which keeps the bundled healthcheck and
the Traefik/Coolify routing consistent. To run on a different external port:

```env
PORT_HTTP=8080      # http://localhost:8080 -> container :3001
```

## Notifications, monitors & status pages

These are configured **in the dashboard**, not here:

- **Monitors** — HTTP(s), TCP, ping, DNS, push, Docker, database, and more.
- **Notifications** — 90+ channels (Email/SMTP, Microsoft Teams, Slack, Telegram,
  Discord, webhooks, …). Add them under *Settings → Notifications*, then attach
  to monitors.
- **Status pages** — public or private aggregate pages under *Status Pages*.

All of it is persisted in the data volume, so it survives restarts and upgrades.
See [backup-and-restore.md](backup-and-restore.md) to protect it.
