
#!/bin/bash
set -euo pipefail

# Load environment variables if .env exists
if [ -f .env ]; then
    source .env
fi

# Variables with defaults
SQL_USER="${MSSQL_USER:-SA}"
SQL_PASSWORD="${MSSQL_SA_PASSWORD:-DevPassword123#}"
SQL_CONTAINER="${SQL_CONTAINER:-vpic-sql}"

echo "Checking table details with proper row counts..."
docker exec ${SQL_CONTAINER} /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -d vpic \
    -Q "
    WITH TableCounts AS (
        SELECT 
            t.TABLE_NAME,
            s.row_count,
            (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) as ColumnCount
        FROM INFORMATION_SCHEMA.TABLES t
        CROSS APPLY (
            SELECT SUM(p.rows) as row_count
            FROM sys.partitions p
            JOIN sys.tables st ON st.object_id = p.object_id
            WHERE st.name = t.TABLE_NAME
            AND p.index_id IN (0,1)
        ) s
        WHERE t.TABLE_TYPE = 'BASE TABLE'
    )
    SELECT 
        TABLE_NAME,
        row_count as RecordCount,
        ColumnCount
    FROM TableCounts
    ORDER BY row_count DESC;"

echo -e "\nChecking specific important tables..."
docker exec ${SQL_CONTAINER} /opt/mssql-tools18/bin/sqlcmd -S localhost \
    -U $SQL_USER -P $SQL_PASSWORD -C \
    -d vpic \
    -Q "
    -- Check Element table
    SELECT 'Element Table Counts:' as Info;
    SELECT COUNT(*) as ElementCount FROM Element;
    SELECT TOP 5 * FROM Element;

    -- Check Pattern table
    SELECT 'Pattern Table Counts:' as Info;
    SELECT COUNT(*) as PatternCount FROM Pattern;
    SELECT TOP 5 * FROM Pattern;

    -- Check Make table
    SELECT 'Make Table Counts:' as Info;
    SELECT COUNT(*) as MakeCount FROM Make;
    SELECT TOP 5 * FROM Make;

    -- Check Model table
    SELECT 'Model Table Counts:' as Info;
    SELECT COUNT(*) as ModelCount FROM Model;
    SELECT TOP 5 * FROM Model;

    -- Database space info
    SELECT 'Database Space Info:' as Info;
    SELECT 
        name,
        size/128.0 as SizeMB,
        CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 as SpaceUsedMB
    FROM sys.database_files;"