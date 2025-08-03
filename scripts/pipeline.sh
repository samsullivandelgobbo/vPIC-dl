#!/usr/bin/env bash
set -euo pipefail

# Function to clean up Docker resources
cleanup_docker() {
    echo "Cleaning up Docker resources..."
    
    # Stop and remove specific containers if they exist
    for container in sqltemp pg_target; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            echo "Stopping and removing container: ${container}"
            docker stop "${container}" 2>/dev/null || true
            docker rm "${container}" 2>/dev/null || true
        fi
    done
    
    # Remove the network if it exists
    if docker network ls | grep -q "docker_default"; then
        echo "Removing network: docker_default"
        docker network rm docker_default 2>/dev/null || true
    fi
}

# Function to wait for SQL Server
wait_for_sqlserver() {
    echo "Waiting for SQL Server to be ready..."
    ATTEMPT=0
    MAX_ATTEMPTS=30
    
    until docker exec sqltemp sqlcmd \
        -S localhost \
        -U SA \
        -P "YourStrong!Passw0rd" \
        -Q "SELECT @@VERSION" \
        -N || [ $ATTEMPT -eq $MAX_ATTEMPTS ]
    do
        ATTEMPT=$((ATTEMPT+1))
        echo "Waiting for SQL Server to start (Attempt $ATTEMPT/$MAX_ATTEMPTS)..."
        sleep 5
    done
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "Error: Could not connect to SQL Server"
        docker logs sqltemp
        exit 1
    fi
    
    echo "SQL Server is ready!"
}

# Function to wait for PostgreSQL
wait_for_postgres() {
    echo "Waiting for PostgreSQL to be ready..."
    ATTEMPT=0
    MAX_ATTEMPTS=30
    
    until docker exec pg_target pg_isready -U postgres &>/dev/null || [ $ATTEMPT -eq $MAX_ATTEMPTS ]
    do
        ATTEMPT=$((ATTEMPT+1))
        echo "Waiting for PostgreSQL to initialize (Attempt $ATTEMPT/$MAX_ATTEMPTS)..."
        sleep 5
    done
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "Error: PostgreSQL failed to start within timeout"
        docker logs pg_target
        exit 1
    fi
    
    echo "PostgreSQL is ready!"
}

# Trap for cleanup on script exit
trap cleanup_docker EXIT

# Initial cleanup
cleanup_docker

# Create temp_data directory if it doesn't exist
mkdir -p temp_data

# 1. Download vPIC data
echo "Downloading vPIC data..."
if [ ! -f temp_data/vpic.bak.zip ]; then
    bash scripts/download_vpic.sh
else
    echo "vPIC data already exists"
fi

# 2. Start containers
echo "Starting Docker containers..."
docker-compose -f docker/docker-compose.yml up -d

# Wait for services to be ready
wait_for_sqlserver
wait_for_postgres

# 3. Restore SQL Server backup
echo "Restoring SQL Server backup..."
bash scripts/restore_and_export.sh

# 4. Run migration script
echo "Running migration script..."
python scripts/migrate.py

# 5. Verify migration
echo "Verifying migration..."
if ! docker exec pg_target psql -U postgres -d vpic -c "\dt"; then
    echo "Error: Failed to verify PostgreSQL migration"
    exit 1
fi

# Create backup of the migrated PostgreSQL database
echo "Creating PostgreSQL backup..."
backup_file="temp_data/vpic_postgres_$(date +%Y%m%d).sql"
if ! docker exec pg_target pg_dump -U postgres vpic > "$backup_file"; then
    echo "Error: Failed to create PostgreSQL backup"
    exit 1
fi
echo "Backup created at: $backup_file"

echo "Pipeline completed successfully!"