# Status Monitor Server Image

Published as `ghcr.io/bauer-group/cs-statusmonitor/status-monitor`.
A thin, professional wrapper around the official
[`louislam/uptime-kuma`](https://hub.docker.com/r/louislam/uptime-kuma) image —
tracking the floating **`2`** tag (latest Uptime Kuma 2.x; major pinned to avoid
a breaking jump to 3.x).

It keeps the upstream image fully intact and only layers on packaging concerns:

| Concern | Upstream image | This image |
| --- | --- | --- |
| Identity / supply chain | generic public image | OCI labels, own GHCR image, SBOM, scans, base-image monitor |
| Reverse-proxy defaults | unset (manual env) | `UPTIME_KUMA_WS_ORIGIN_CHECK` + iframe policy baked as sane defaults |
| Boot visibility | silent | branded banner echoing the effective runtime config |

## What it does NOT change

Unlike the broker stacks, Uptime Kuma needs no boot-time provisioning — all
configuration (monitors, notifications, status pages, the admin account) is
created in the web UI and persisted to the data volume. So this wrapper adds
**no** init logic, **no** TLS handling (the reverse proxy terminates HTTPS) and
**no** secrets.

The upstream runtime contract is preserved verbatim:

| Property | Value |
| --- | --- |
| Working dir | `/app` |
| Data dir | `/app/data` (mount a volume here) |
| Port | `3001` (HTTP + socket.io) |
| Healthcheck | `extra/healthcheck` (bundled, hits the local port) |
| PID 1 | `dumb-init` (signal handling / zombie reaping unchanged) |
| Command | `node server/server.js` |

## Entrypoint chain

```
/usr/bin/dumb-init -- /usr/local/bin/docker-entrypoint-custom.sh node server/server.js
                      └── prints banner, then exec "$@"
```

`dumb-init` stays PID 1; the custom script is a transparent shim that prints the
banner and `exec`s the original command.

## Build

```bash
docker build \
  --build-arg UPTIME_KUMA_VERSION=2 \
  -t ghcr.io/bauer-group/cs-statusmonitor/status-monitor:local .
```

## Environment

| Variable | Default | Purpose |
| --- | --- | --- |
| `UPTIME_KUMA_HOST` | `::` | bind address inside the container |
| `UPTIME_KUMA_PORT` | `3001` | listen port |
| `UPTIME_KUMA_WS_ORIGIN_CHECK` | `cors-like` | WebSocket Origin verification (`bypass` to disable) |
| `UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN` | `false` | allow embedding status pages in an iframe |
| `TZ` | `Etc/UTC` | container timezone |

See the repository root `README.md` and `docs/` for full deployment guidance.
