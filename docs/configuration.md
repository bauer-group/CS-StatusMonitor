# Configuration

Everything in this stack is driven from `.env`. Uptime Kuma itself stores its
runtime configuration (monitors, notifications, status pages, users) in its
database inside the data volume — **not** in environment variables.

## Environment variables

| Variable | Default | Used by | Purpose |
| --- | --- | --- | --- |
| `STACK_NAME` | `status_example_domain_com` | all | prefix for container/volume/network names |
| `TIME_ZONE` | `Etc/UTC` | all | container timezone (`TZ`) |
| `STATUS_MONITOR_IMAGE` | `ghcr.io/bauer-group/cs-statusmonitor/status-monitor` | single/traefik/coolify | our published image to pull |
| `STATUS_MONITOR_IMAGE_VERSION` | `latest` | single/traefik/coolify | our published image tag |
| `UPTIME_KUMA_REPOSITORY` | `louislam/uptime-kuma` | development | upstream base image to build from |
| `UPTIME_KUMA_VERSION` | `2` | development | upstream base tag (floating 2.x) |
| `UPTIME_KUMA_HOST` | *(unset → dual-stack `[::]`, IPv6+IPv4)* | all | bind address; set `0.0.0.0` only to force IPv4-only |
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
docker compose -f docker-compose.single.yml exec status-monitor \
  node extra/reset-password.js
```

## Bind address (`UPTIME_KUMA_HOST`)

**Leave it unset (the default).** When `UPTIME_KUMA_HOST` is not set, Uptime Kuma
binds a single dual-stack socket on `[::]:3001`, which serves **both IPv6 and
IPv4** (via v4-mapped addresses, since Linux defaults `bindv6only=0`). The
compose files declare it as a no-value pass-through, so it is only sent to the
container when you actually set it in `.env`.

Two things to avoid:

- **Don't set it to an explicit `::`.** It binds the same dual-stack socket, but
  Uptime Kuma then logs a harmless `Error printing server URLs: Invalid URL`
  while building its startup banner (an unbracketed `::` isn't a valid URL host).
  The app still runs — it's cosmetic — but leaving the variable unset avoids the
  noise entirely.
- **Don't pass it as an empty string.** Uptime Kuma coerces `""` back to `::`,
  reintroducing the same log line.

Set it only to **force IPv4-only** (drops IPv6):

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
