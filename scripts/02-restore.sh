#!/bin/bash
set -euo pipefail

echo "Starting backup restoration process..."

# Load environment variables if .env exists
if [ -f .env ]; then
    source .env
fi

# Variables with defaults
TEMP_DIR="${TEMP_DATA_DIR:-temp}"
SQL_USER="${MSSQL_USER:-SA}"
SQL_PASSWORD="${MSSQL_SA_PASSWORD:-DevPassword123#}"
SQL_CONTAINER="${SQL_CONTAINER:-vpic-sql}"

# Find the .bak file dynamically
BAK_FILE=$(find "$TEMP_DIR" -name "VPICList_lite_*.bak" -type f | head -n 1)

if [ -z "$BAK_FILE" ]; then
    echo "Error: No .bak file found in $TEMP_DIR"
    exit 1
fi

echo "Found backup file: $BAK_FILE"
BACKUP_FILENAME=$(basename "$BAK_FILE")
BACKUP_FILE="/var/opt/mssql/backup/$BACKUP_FILENAME"

# Check if the backup file exists in the container
docker exec ${SQL_CONTAINER} ls -l $BACKUP_FILE || {
    echo "Error: Backup file not found in container at $BACKUP_FILE"
    exit 1
}

# Get logical file names from backup
echo "Getting logical file names from backup..."
docker exec ${SQL_CONTAINER} /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "RESTORE FILELISTONLY FROM DISK = '$BACKUP_FILE'"

# Create restore command with correct logical file names
echo "Restoring database..."
docker exec ${SQL_CONTAINER} /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "RESTORE DATABASE vpic 
        FROM DISK = '$BACKUP_FILE' 
        WITH MOVE 'vPICList_Lite1' TO '/var/opt/mssql/data/vpic.mdf',
        MOVE 'vPICList_Lite1_log' TO '/var/opt/mssql/data/vpic_log.ldf',
        REPLACE"

# Verify restoration
echo "Verifying database restoration..."
docker exec ${SQL_CONTAINER} /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "SELECT DB_NAME(database_id) as DatabaseName, 
        state_desc as Status 
        FROM sys.databases 
        WHERE name = 'vpic'"

# Get table counts and names
echo "Getting database information..."
docker exec ${SQL_CONTAINER} /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -d vpic \
    -Q "SELECT 
            t.TABLE_NAME, 
            (SELECT COUNT(*) FROM vpic.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) as ColumnCount,
            (SELECT COUNT_BIG(*) FROM vpic.sys.tables st 
             INNER JOIN vpic.sys.partitions p ON st.object_id = p.object_id 
             WHERE st.name = t.TABLE_NAME) as RowCount
        FROM vpic.INFORMATION_SCHEMA.TABLES t
        WHERE TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_NAME;"