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

# Check usage of partition
