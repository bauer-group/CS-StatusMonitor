#!/usr/bin/env bash
# =============================================================================
# BAUER GROUP Status Monitor - Custom Entrypoint
# =============================================================================
# A deliberately tiny wrapper: Uptime Kuma needs no boot-time provisioning
# (everything lives in its web-UI-managed data volume). This script only:
#   1. prints a branded banner echoing the effective runtime configuration
#   2. exec's the original command (node server/server.js)
#
# It runs under dumb-init (PID 1), so signal handling and zombie reaping are
# unchanged from the upstream image. No TLS, no config rendering, no secrets.
# =============================================================================
set -euo pipefail

# --- Defaults (also declared in the Dockerfile / .env.example) ---------------
# UPTIME_KUMA_HOST is intentionally NOT defaulted here: leaving it unset lets
# Uptime Kuma bind dual-stack [::] (IPv6 + IPv4) without its "Invalid URL" log
# noise. The banner below shows the effective value with a display-only fallback.
: "${UPTIME_KUMA_PORT:=3001}"
: "${UPTIME_KUMA_WS_ORIGIN_CHECK:=cors-like}"
: "${UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN:=false}"

log() { printf '%s\n' "$*"; }

banner() {
  log "============================================="
  log " BAUER GROUP Status Monitor (Uptime Kuma)"
  log "============================================="
  log "Hostname            : ${HOSTNAME:-unknown}"
  log "Timezone            : ${TZ:-Etc/UTC}"
  log "Bind address        : ${UPTIME_KUMA_HOST:-:: (dual-stack, IPv6+IPv4)}"
  log "Port                : ${UPTIME_KUMA_PORT}"
  log "Data directory      : /app/data"
  log "WS origin check     : ${UPTIME_KUMA_WS_ORIGIN_CHECK}"
  log "Frame same-origin   : disabled=${UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN}"
  log "============================================="
  log "First run? Open the dashboard and complete the"
  log "setup wizard to create the admin account."
  log "============================================="
}

banner

log "Starting Uptime Kuma: $*"
exec "$@"
