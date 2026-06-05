# Backup & Restore

**Everything** Uptime Kuma knows — monitors, heartbeat history, notifications,
status pages, users, settings — lives in the database under `/app/data`, which
is the `${STACK_NAME}-data` Docker volume. Back up that volume and you have a
complete, portable backup. Nothing of value lives in the repo or `.env`.

## What's in the volume

| Path | Contents |
| --- | --- |
| `/app/data/` | database, uploads, generated config — the whole application state |

The named volume resolves to `${STACK_NAME}-data` (e.g. `status_example_domain_com-data`).

## Back up (cold — recommended)

A cold backup (container stopped) guarantees a consistent database snapshot:

```bash
COMPOSE=docker-compose.single.yml

docker compose -f $COMPOSE stop status-monitor

# Tar the volume contents to ./backup/ on the host
docker run --rm \
  -v ${STACK_NAME:-status-monitor}-data:/data:ro \
  -v "$(pwd)/backup":/backup \
  alpine tar czf /backup/status-monitor-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

docker compose -f $COMPOSE start status-monitor
```

## Back up (hot)

If you can't stop the service, a hot tar usually works because Uptime Kuma 2.x
uses a journaled database — but a cold backup is the only one guaranteed
consistent. For zero-downtime guarantees, snapshot at the storage layer (LVM /
ZFS / cloud volume snapshot) instead.

## Restore

```bash
COMPOSE=docker-compose.single.yml

docker compose -f $COMPOSE down

# Recreate an empty volume and extract the archive into it
docker volume create ${STACK_NAME:-status-monitor}-data
docker run --rm \
  -v ${STACK_NAME:-status-monitor}-data:/data \
  -v "$(pwd)/backup":/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/<your-backup>.tar.gz -C /data"

docker compose -f $COMPOSE up -d
```

## Migrating to another host

1. Cold-backup the volume on the old host (above).
2. Copy the `.tar.gz` and your `.env` to the new host.
3. Restore the volume, then `docker compose ... up -d`.

The admin account and all history come back exactly as they were — there is no
separate credential to re-enter.

## Automate it

Schedule the cold-backup snippet (e.g. a nightly cron / systemd timer) and ship
the archives off-host. Keep a rolling window (e.g. 14 daily + 8 weekly) and
**test a restore periodically** — an untested backup is a hope, not a backup.
