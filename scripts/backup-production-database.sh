#!/bin/bash
set -e

BACKUP_FILE="backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
echo "Creating backup: $BACKUP_FILE"
bunx supabase db dump --linked > "$BACKUP_FILE"
echo "Backup complete: $BACKUP_FILE"
