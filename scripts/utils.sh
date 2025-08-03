#!/bin/bash
set -euo pipefail

# Common database connection settings
source .env 2>/dev/null || true

# Default values if not set in .env
SQL_USER="${SQL_USER:-SA}"
SQL_PASSWORD="${SQL_PASSWORD:-DevPassword123#}"
PG_USER="${PG_USER:-postgres}"
PG_PASSWORD="${PG_PASSWORD:-postgres}"

# Container names
SQL_CONTAINER="${SQL_CONTAINER:-sqltemp}"
PG_CONTAINER="${PG_CONTAINER:-pg_target}"

wait_for_sqlserver() {
    echo "Waiting for SQL Server to be ready..."
    ATTEMPT=0
    MAX_ATTEMPTS=30
    
    until docker exec "$SQL_CONTAINER" /opt/mssql-tools18/bin/sqlcmd \
        -S localhost \
        -U "$SQL_USER" \
        -P "$SQL_PASSWORD" \
        -C \
        -Q "SELECT @@VERSION" &>/dev/null
    do
        ATTEMPT=$((ATTEMPT+1))
        echo "Waiting... ($ATTEMPT/$MAX_ATTEMPTS)"
        [ $ATTEMPT -eq $MAX_ATTEMPTS ] && return 1
        sleep 2
    done
    
    echo "SQL Server is ready!"
    return 0
}

wait_for_postgres() {
    echo "Waiting for PostgreSQL to be ready..."
    ATTEMPT=0
    MAX_ATTEMPTS=30
    
    until docker exec "$PG_CONTAINER" pg_isready -U "$PG_USER" &>/dev/null
    do
        ATTEMPT=$((ATTEMPT+1))
        echo "Waiting... ($ATTEMPT/$MAX_ATTEMPTS)"
        [ $ATTEMPT -eq $MAX_ATTEMPTS ] && return 1
        sleep 2
    done
    
    echo "PostgreSQL is ready!"
    return 0
}

verify_sqlserver_connection() {
    echo "Verifying SQL Server connection..."
    docker exec "$SQL_CONTAINER" /opt/mssql-tools18/bin/sqlcmd \
        -S localhost \
        -U "$SQL_USER" \
        -P "$SQL_PASSWORD" \
        -C \
        -Q "SELECT DB_NAME(database_id) as DatabaseName, 
            state_desc as Status 
            FROM sys.databases 
            WHERE name = 'vpic'"
}

verify_postgres_connection() {
    echo "Verifying PostgreSQL connection..."
    docker exec "$PG_CONTAINER" psql \
        -U "$PG_USER" \
        -d vpic \
        -c "\dt+"
}

# Database backup functions
backup_postgres() {
    local backup_dir="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_base="${backup_dir}/vpic_postgres_${timestamp}"

    echo "Creating PostgreSQL backups..."
    
    # Schema only backup
    docker exec "$PG_CONTAINER" pg_dump \
        -U "$PG_USER" \
        -d vpic \
        --schema-only > "${backup_base}_schema.sql"
    
    # Data only backup
    docker exec "$PG_CONTAINER" pg_dump \
        -U "$PG_USER" \
        -d vpic \
        --data-only > "${backup_base}_data.sql"
    
    # Complete backup in custom format
    docker exec "$PG_CONTAINER" pg_dump \
        -U "$PG_USER" \
        -d vpic \
        -Fc > "${backup_base}.dump"
    
    echo "Backups created at: ${backup_base}*"
}