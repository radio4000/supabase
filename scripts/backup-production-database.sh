#!/bin/bash
set -e

# Requires: supabase link --project-ref <ref> (run once to authenticate)

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
ROLES_FILE="$BACKUP_DIR/backup_${TIMESTAMP}_roles.sql"
SCHEMA_FILE="$BACKUP_DIR/backup_${TIMESTAMP}_schema.sql"
DATA_FILE="$BACKUP_DIR/backup_${TIMESTAMP}_data.sql"

# Create backups directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Creating roles backup: $ROLES_FILE"
bunx supabase db dump --linked --role-only > "$ROLES_FILE"
echo "Roles backup complete: $ROLES_FILE ($(du -h "$ROLES_FILE" | cut -f1))"

echo "Creating schema backup: $SCHEMA_FILE"
bunx supabase db dump --linked > "$SCHEMA_FILE"
echo "Schema backup complete: $SCHEMA_FILE ($(du -h "$SCHEMA_FILE" | cut -f1))"

echo "Creating data backup: $DATA_FILE"
bunx supabase db dump --linked --data-only --use-copy > "$DATA_FILE"
echo "Data backup complete: $DATA_FILE ($(du -h "$DATA_FILE" | cut -f1))"

echo "Created backups of Radio4000 production database roles, schema, and data"
