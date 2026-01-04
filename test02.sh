#!/usr/bin/env tcsh
# PostgreSQL backup script (tcsh)
# Configure via env: PGHOST, PGPORT, PGUSER, PGDATABASE (use "all"), BACKUP_DIR, RETENTION_DAYS, PGPASSWORD (or use ~/.pgpass)

# Defaults
if (! ${?PGHOST}) setenv PGHOST localhost
if (! ${?PGPORT}) setenv PGPORT 5432
if (! ${?PGUSER}) setenv PGUSER postgres
if (! ${?PGDATABASE}) setenv PGDATABASE db_mz
if (! ${?BACKUP_DIR}) setenv BACKUP_DIR /var/db/postgres/backups
if (! ${?RETENTION_DAYS}) setenv RETENTION_DAYS 30

set TS = `date -u +%Y-%m-%d%H%M%S`

# Simple logger
alias log 'echo `date -u +%Y-%m-%d %H:%M:%S` \!*'

# require commands
foreach cmd (psql pg_dump pg_dumpall gzip find mkdir date)
  which ${cmd} >& /dev/null
  if (${status} != 0) then
    echo "`date -u +%Y-%m-%d %H:%M:%S` required command \"${cmd}\" not found" >&2
    exit 2
  endif
end

# ensure backup dir exists
/bin/mkdir -p "${BACKUP_DIR}"

log "Starting PostgreSQL backup (host=${PGHOST} port=${PGPORT} user=${PGUSER} db=${PGDATABASE})"

# Dump globals
log "Dumping globals"
pg_dumpall -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} --globals-only | gzip > "${BACKUP_DIR}/pg_globals_${TS}.sql.gz"
if (${status} == 0) then
  log "Saved globals -> ${BACKUP_DIR}/pg_globals_${TS}.sql.gz"
else
  echo "`date -u +%Y-%m-%d %H:%M:%S` Failed to dump globals" >&2
  exit 1
endif

# Dump databases
if ("${PGDATABASE}" == "all") then
  set dbs = (`psql -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -At -c 'SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn;'`)
  foreach db (${dbs})
    set out = "${BACKUP_DIR}/${db}_${TS}.dump"
    log "Backing up database: ${db} -> ${out}"
    pg_dump -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -Fc -d ${db} -f "${out}"
    if (${status} != 0) then
      echo "`date -u +%Y-%m-%dT%H:%M:%SZ` pg_dump failed for ${db}" >&2
      exit 1
    endif
    gzip -f "${out}"
  end
else
  set out = "${BACKUP_DIR}/${PGDATABASE}_${TS}.dump"
  log "Backing up database: ${PGDATABASE} -> ${out}"
  pg_dump -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -Fc -d ${PGDATABASE} -f "${out}"
  if (${status} != 0) then
    echo "`date -u +%Y-%m-%dT%H:%M:%SZ` pg_dump failed for ${PGDATABASE}" >&2
    exit 1
  endif
  gzip -f "${out}"
endif

# Rotate old backups
log "Removing backups older than ${RETENTION_DAYS} days"
find "${BACKUP_DIR}" -type f -name "*.dump" -mtime +${RETENTION_DAYS} -print -delete || true

log "Backup completed successfully"
exit 0