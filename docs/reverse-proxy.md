# Reverse Proxy & TLS

Uptime Kuma speaks plain **HTTP on port 3001** and also serves a **socket.io
WebSocket** on the same port (the live dashboard depends on it). TLS is
terminated by the reverse proxy in front of it — the container itself is never
exposed directly in the Traefik/Coolify modes.

## The two things a proxy must get right

1. **Forward the `Host` header.** Uptime Kuma's WebSocket Origin check
   (`UPTIME_KUMA_WS_ORIGIN_CHECK=cors-like`) compares the browser `Origin`
   against the server hostname. Traefik and Coolify forward `Host` correctly out
   of the box, so the default secure setting works.
2. **Allow the WebSocket upgrade.** socket.io needs the `Upgrade`/`Connection`
   headers to pass through. Traefik and Coolify do this automatically on a
   normal HTTP router; a hand-rolled nginx needs it configured explicitly
   (below).

## Traefik (`docker-compose.traefik.yml`)

The compose file ships the full label set: an HTTP→HTTPS redirect router, an
HTTPS router with the `letsencrypt` cert resolver, and a service pointing at
container port `3001`. WebSockets are upgraded transparently over the same
router — **no extra Traefik configuration is required**.

Prerequisites:

- Traefik attached to the external `${PROXY_NETWORK}` network
- `web` (:80) and `web-secure` (:443) entrypoints and a `letsencrypt`
  cert resolver configured on your Traefik instance
- DNS: `${SERVICE_HOSTNAME}` → this host

## Coolify (`docker-compose.coolify.yml`)

Set the service **Domain** to `https://${SERVICE_HOSTNAME}` on port `3001` in
the Coolify dashboard. Coolify generates the Traefik routers and manages the
certificate; this compose file only exposes the port.

## Generic nginx (reference)

If you front it with your own nginx instead, the WebSocket upgrade must be
explicit:

```nginx
location / {
    proxy_pass http://127.0.0.1:3001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade           $http_upgrade;
    proxy_set_header Connection        "upgrade";
    proxy_set_header Host              $host;       # keeps the Origin check happy
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

## Troubleshooting

- **Dashboard loads but shows "Disconnected" / keeps reconnecting** — the
  WebSocket isn't getting through, or the Origin check is rejecting it. First
  confirm the proxy forwards the `Upgrade`/`Connection` headers and `Host`. As a
  last resort behind an unusual proxy, set `UPTIME_KUMA_WS_ORIGIN_CHECK=bypass`
  in `.env` and restart.
- **Embedding a status page in another site fails** — set
  `UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN=true` to lift the same-origin iframe
  restriction.
