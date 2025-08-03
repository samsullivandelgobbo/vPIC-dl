# src/settings.py
import os
from pathlib import Path

# Base paths
PROJECT_ROOT = Path(__file__).parent.parent
TEMP_DATA_DIR = PROJECT_ROOT / "temp"
MIGRATIONS_DIR = PROJECT_ROOT / "migrations"

# Database configurations
SQL_SERVER = {
    "driver": "ODBC Driver 18 for SQL Server",
    "server": "localhost",
    "database": "vpic",
    "user": "SA",
    "password": "DevPassword123#",
    "trust_cert": "yes"
}

# Updated PostgreSQL settings to match working container configuration
POSTGRES = {
    "host": "localhost",
    "port": "5432",
    "dbname": "vpic",  # Start with default database
    "user": "postgres",
    "password": "postgres",
    "connect_timeout": 10
}

# Docker configurations
DOCKER = {
    "compose_file": PROJECT_ROOT / "docker" / "docker-compose.yml",
    "sql_container": "sqltemp",
    "pg_container": "pg_target",
    "network": "docker_default"
}

# vPIC configurations
VPIC = {
    "api_url": "https://vpic.nhtsa.dot.gov/api/",
    "backup_file": "VPICList_lite_2024_12.bak"
}

# Type mappings
SQL_TO_PG_TYPES = {
    "bigint": "bigint",
    "bit": "boolean",
    "decimal": "decimal",
    "int": "integer",
    "money": "decimal(19,4)",
    "numeric": "numeric",
    "smallint": "smallint",
    "smallmoney": "decimal(10,4)",
    "tinyint": "smallint",
    "float": "double precision",
    "real": "real",
    "date": "date",
    "datetime2": "timestamp",
    "datetime": "timestamp",
    "datetimeoffset": "timestamp with time zone",
    "smalldatetime": "timestamp",
    "time": "time",
    "char": "char",
    "varchar": "varchar",
    "text": "text",
    "nchar": "char",
    "nvarchar": "varchar",
    "ntext": "text",
    "binary": "bytea",
    "varbinary": "bytea",
    "image": "bytea",
    "uniqueidentifier": "uuid",
}

# Add SQLite configuration and type mappings
SQLITE = {
    "database": TEMP_DATA_DIR / "vpic.db",
    "pragmas": {
        "journal_mode": "WAL",
        "synchronous": "NORMAL",
        "foreign_keys": "ON",
        "cache_size": -64000  # 64MB cache
    }
}

# Add SQLite type mappings
SQL_TO_SQLITE_TYPES = {
    "bigint": "INTEGER",
    "bit": "INTEGER",
    "decimal": "REAL",
    "int": "INTEGER",
    "money": "REAL",
    "numeric": "REAL",
    "smallint": "INTEGER",
    "smallmoney": "REAL",
    "tinyint": "INTEGER",
    "float": "REAL",
    "real": "REAL",
    "date": "TEXT",
    "datetime2": "TEXT",
    "datetime": "TEXT",
    "datetimeoffset": "TEXT",
    "smalldatetime": "TEXT",
    "time": "TEXT",
    "char": "TEXT",
    "varchar": "TEXT",
    "text": "TEXT",
    "nchar": "TEXT",
    "nvarchar": "TEXT",
    "ntext": "TEXT",
    "binary": "BLOB",
    "varbinary": "BLOB",
    "image": "BLOB",
    "uniqueidentifier": "TEXT",
}