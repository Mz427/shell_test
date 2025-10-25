#!/usr/bin/env bash
# PostgreSQL backup script
# Configure via env: PGHOST, PGPORT, PGUSER, PGDATABASE (use "all"), BACKUP_DIR, RETENTION_DAYS, PGPASSWORD (or use ~/.pgpass)

set -euo pipefail
IFS=$'\n\t'

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-all}"    # set to a single db name or "all"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TS="$(date -u +'%Y-%m-%dT%H%M%SZ')"

mkdir -p "$BACKUP_DIR"

log() { printf '%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "required command '$1' not found"; exit 2; }
}

require_cmd psql
require_cmd pg_dump
require_cmd pg_dumpall
require_cmd gzip
require_cmd find

trap 'log "Backup failed"; exit 1' ERR

log "Starting PostgreSQL backup (host=$PGHOST port=$PGPORT user=$PGUSER db=$PGDATABASE)"

# Dump cluster-wide roles/privileges
log "Dumping globals"
if pg_dumpall -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" --globals-only | gzip > "$BACKUP_DIR/pg_globals_$TS.sql.gz"; then
  log "Saved globals -> $BACKUP_DIR/pg_globals_$TS.sql.gz"
else
  log "Failed to dump globals"
  exit 1
fi

# Dump databases
if [ "$PGDATABASE" = "all" ]; then
  dbs=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -At -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn;" )
  for db in $dbs; do
    out="$BACKUP_DIR/${db}_$TS.dump"
    log "Backing up database: $db -> $out"
    pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -Fc -d "$db" -f "$out"
    log "Compressing $out"
    gzip -f "$out"
  done
else
  out="$BACKUP_DIR/${PGDATABASE}_$TS.dump"
  log "Backing up database: $PGDATABASE -> $out"
  pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -Fc -d "$PGDATABASE" -f "$out"
  gzip -f "$out"
fi

# Rotate old backups
log "Removing backups older than $RETENTION_DAYS days"
find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -print -delete || true

log "Backup completed successfully"
exit 0