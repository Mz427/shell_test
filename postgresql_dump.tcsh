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

# Ensure backup directory exists
mkdir -p ${BACKUP_DIR}

# Check usage of partition
set cap_partition = `df -h ${BACKUP_DIR} | awk 'FNR == 2 {printf "%s", $5}'`
if (${cap_partition:s/%//} > 90) then
    printf "Error: Disk usage above 90%% in %s\n" ${BACKUP_DIR}
    exit 1
endif

# Get timestamp
alias datestamp 'date "+%Y-%m-%d/%H:%M:%S"'
set timestamp = `date '+%Y%m%d%H%M%S'`

# Perform backup
if (${PGDATABASE} == "all") then
    set backup_file = "${BACKUP_DIR}/backup_all_${timestamp}.gz"
    printf "%s: Starting backup of all databases to %s\n" `datestamp` ${backup_file}
    pg_dumpall | gzip > ${backup_file}
else
    set backup_file = "${BACKUP_DIR}/backup_${PGDATABASE}_${timestamp}.gz"
    printf "%s: Starting backup of database %s to %s\n" `datestamp` ${PGDATABASE} ${backup_file}
    pg_dump ${PGDATABASE} | gzip > ${backup_file}
endif

printf "%s: Backup completed: %s\n" `datestamp` ${backup_file}

# Clean up old backups
printf "%s: Cleaning up backups older than %d days:\n" `datestamp` ${RETENTION_DAYS}
find ${BACKUP_DIR} -name "backup_*.gz" -mtime +${RETENTION_DAYS} -exec rm -v {} \;