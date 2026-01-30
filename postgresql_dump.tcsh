#!/usr/bin/env tcsh
# PostgreSQL backup script (tcsh)
# Configure via env: PGHOST, PGPORT, PGUSER, PGDATABASE (use "all"), BACKUP_DIR, RETENTION_DAYS, PGPASSWORD (or use ~/.pgpass)

# Defaults
set pghost = "localhost"
set pgport = 5432
set pguser = "postgres"
set pgdatabase = "db_mz"
set backup_dir = "/var/db/postgres/backups"
set retention_days = 30
# Get timestamp
alias timestamp 'date "+%Y/%m/%d-%H:%M:%S"'
set file_suffix = `date '+%Y%m%d%H%M%S'`

# Ensure backup directory exists
mkdir -p ${backup_dir}
# Check usage of partition
set cap_partition = `df -h ${backup_dir} | awk 'FNR == 2 {printf "%s", $5}'`
if (${cap_partition:s/%//} > 90) then
    printf "Error: Disk usage above 90%% in %s\n" ${backup_dir}
    exit 1
endif

# Perform backup
if (${#argv} == 1) then
    set pgdatabase = ${argv[1]}
endif
set backup_file = "${backup_dir}/backup_${pgdatabase}_${file_suffix}.gz"
printf "%s: Starting backup of %s database to %s\n" `timestamp` ${pgdatabase} ${backup_file}
if (${pgdatabase} == "all") then
    pg_dumpall -h ${pghost} -p ${pgport} -U ${pguser} | gzip > ${backup_file}
    if (${status} != 0) then
        printf "%s: Error during pg_dumpall\n" `timestamp`
        exit 1
    endif
else
    foreach i (`psql -Atc "SELECT datname FROM pg_database WHERE datistemplate = false;"`)
        if (${i} == ${pgdatabase}) then
            set db_found = 1
            pg_dump -h ${pghost} -p ${pgport} -U ${pguser} ${pgdatabase} | gzip > ${backup_file}
            if (${status} != 0) then
                printf "%s: Error during pg_dump of database %s\n" `timestamp` ${pgdatabase}
                exit 1
            endif
            break
        endif
    end
    if (! ${?db_found}) then
        printf "%s: Error: Database %s does not exist\n" `timestamp` ${pgdatabase}
        exit 1
    endif
endif
printf "%s: Backup completed: %s\n" `timestamp` ${backup_file}

# Clean up old backups
printf "%s: Cleaning up backups older than %d days:\n" `timestamp` ${retention_days}
find ${backup_dir} -name "backup_*.gz" -mtime +${retention_days} -exec rm -v {} \;