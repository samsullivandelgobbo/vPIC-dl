#!/bin/bash
set -euo pipefail

echo "Building and starting containers..."
docker-compose down -v
docker-compose build
docker-compose up -d

echo "Waiting for SQL Server to be ready..."
sleep 20

echo "Testing SQL Server connection..."
docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd \
    -S localhost \
    -U SA \
    -P "DevPassword123#" \
    -C \
    -Q "SELECT @@VERSION"

if [ $? -eq 0 ]; then
    echo "SQL Server is running and accessible!"
    
    # Test creating a database and table
    echo "Testing database operations..."
    docker exec sqltemp /opt/mssql-tools18/bin/sqlcmd \
        -S localhost \
        -U SA \
        -P "DevPassword123#" \
        -C \
        -Q "CREATE DATABASE TestDB; USE TestDB; CREATE TABLE TestTable (ID INT); INSERT INTO TestTable VALUES (1); SELECT * FROM TestTable;"
else
    echo "Failed to connect to SQL Server"
    docker logs sqltemp
    exit 1
fi

echo "Testing Postgres connection..."
docker exec postgrestemp psql -U postgres -d postgres -c "SELECT version();"

if [ $? -eq 0 ]; then
    echo "Postgres is running and accessible!"
    
    # Test creating a database and table
    echo "Testing database operations..."
    docker exec postgrestemp psql -U postgres -d postgres -c "CREATE DATABASE TestDB; \c TestDB; CREATE TABLE TestTable (ID INT); INSERT INTO TestTable VALUES (1); SELECT * FROM TestTable;"
else
    echo "Failed to connect to Postgres"
    docker logs postgrestemp
    exit 1
fi

