#!/bin/bash
set -euo pipefail

echo "Starting backup restoration process..."

# Variables 

BACKUP_FILE="/var/opt/mssql/backup/VPICList_lite_2025_01.bak"
SQL_USER="SA"
SQL_PASSWORD="DevPassword123#"

# First, let's check if the backup file exists in the container
docker exec sqltemp ls -l $BACKUP_FILE || {
    echo "Error: Backup file not found in container"
    exit 1
}

# Get logical file names from backup
echo "Getting logical file names from backup..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "RESTORE FILELISTONLY FROM DISK = '$BACKUP_FILE'"

# Create restore command with correct logical file names
echo "Restoring database..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "RESTORE DATABASE vpic 
        FROM DISK = '$BACKUP_FILE' 
        WITH MOVE 'vPICList_Lite1' TO '/var/opt/mssql/data/vpic.mdf',
        MOVE 'vPICList_Lite1_log' TO '/var/opt/mssql/data/vpic_log.ldf',
        REPLACE"

# Verify restoration
echo "Verifying database restoration..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -Q "SELECT DB_NAME(database_id) as DatabaseName, 
        state_desc as Status 
        FROM sys.databases 
        WHERE name = 'vpic'"

# Get table counts and names
echo "Getting database information..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd -S localhost \
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