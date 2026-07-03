# ===============================================================================
# BAUER GROUP Status Monitor - Uptime Kuma Container Image
# ===============================================================================
# Thin, professional wrapper around the official louislam/uptime-kuma image.
#
# Adds:
#   - OCI image labels + BAUER GROUP supply chain (own GHCR image, SBOM, scans)
#   - Sensible reverse-proxy defaults (WS origin check, iframe policy)
#   - A branded boot banner that echoes the effective runtime configuration
#
# It deliberately keeps the upstream runtime contract intact: same data dir
# (/app/data), same port (3001), same healthcheck (extra/healthcheck), and
# dumb-init stays PID 1 for correct signal handling / zombie reaping.
#
# Documentation: https://github.com/bauer-group/CS-StatusMonitor
# ===============================================================================

# ---------------------------------------------------------------------------
# Build Arguments
# ---------------------------------------------------------------------------
# Floating tag: tracks the latest Uptime Kuma 2.x (major pinned to avoid a
# breaking jump to 3.x). The base-image monitor rebuilds when the digest moves.
ARG UPTIME_KUMA_REPOSITORY=louislam/uptime-kuma
ARG UPTIME_KUMA_VERSION=2

# ---------------------------------------------------------------------------
# Base Image
# ---------------------------------------------------------------------------
FROM ${UPTIME_KUMA_REPOSITORY}:${UPTIME_KUMA_VERSION}

# ---------------------------------------------------------------------------
# Metadata Labels (Legacy)
# ---------------------------------------------------------------------------
LABEL vendor="BAUER GROUP"
LABEL maintainer="Karl Bauer <karl.bauer@bauer-group.com>"

# ---------------------------------------------------------------------------
# OCI Image Spec Labels
# https://github.com/opencontainers/image-spec/blob/main/annotations.md
# ---------------------------------------------------------------------------
LABEL org.opencontainers.image.title="Status Monitor (Uptime Kuma)"
LABEL org.opencontainers.image.description="Uptime Kuma status & uptime monitoring - BAUER GROUP Edition (reverse-proxy defaults, branded boot, CI/CD supply chain)"
LABEL org.opencontainers.image.vendor="BAUER GROUP"
LABEL org.opencontainers.image.authors="Karl Bauer <karl.bauer@bauer-group.com>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/bauer-group/CS-StatusMonitor"
LABEL org.opencontainers.image.url="https://github.com/bauer-group/CS-StatusMonitor"
LABEL org.opencontainers.image.documentation="https://github.com/bauer-group/CS-StatusMonitor#readme"
LABEL org.opencontainers.image.version="0.2.0"

# ---------------------------------------------------------------------------
# Reverse-proxy friendly defaults (overridable via compose .env)
# ---------------------------------------------------------------------------
# Bind address: deliberately NOT set. Uptime Kuma's built-in default binds
# dual-stack [::] (full IPv6 + IPv4 via v4-mapped), which is exactly what we
# want. Setting it explicitly to "::" binds the same socket but makes Uptime
# Kuma log a harmless "Error printing server URLs: Invalid URL" (an unbracketed
# "::" is not a valid URL host for its startup banner); leaving it unset avoids
# that code path entirely. Set UPTIME_KUMA_HOST=0.0.0.0 only to force IPv4-only.
ENV UPTIME_KUMA_WS_ORIGIN_CHECK=cors-like \
    UPTIME_KUMA_DISABLE_FRAME_SAMEORIGIN=false

# ---------------------------------------------------------------------------
# Custom Entrypoint (banner + exec; dumb-init remains PID 1)
# ---------------------------------------------------------------------------
COPY docker-entrypoint-custom.sh /usr/local/bin/docker-entrypoint-custom.sh
RUN chmod a+rx /usr/local/bin/docker-entrypoint-custom.sh

# ---------------------------------------------------------------------------
# Ports
# ---------------------------------------------------------------------------
# 3001  HTTP dashboard / status pages / socket.io
EXPOSE 3001

# ---------------------------------------------------------------------------
# Health Check (mirrors upstream — bundled checker hits the local port)
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=5 \
    CMD extra/healthcheck

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
# Upstream entrypoint is dumb-init; we slot our banner script in between so
# dumb-init stays PID 1 and our script just exec's the CMD.
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/docker-entrypoint-custom.sh"]
CMD ["node", "server/server.js"]
