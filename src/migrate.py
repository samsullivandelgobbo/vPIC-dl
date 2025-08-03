# src/migrate.py
import logging
import os
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Type
from tqdm import tqdm

from database import (
    DatabaseConnection,
    SQLServer,
    PostgreSQL,
    SQLite,
    ensure_database
)
from settings import (
    SQL_TO_PG_TYPES,
    SQL_TO_SQLITE_TYPES,
    SQLITE
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_table_schema(sql_conn: SQLServer) -> Dict[str, List[Tuple]]:
    """Extract schema information from SQL Server"""
    tables = {}
    query = """
    SELECT 
        t.name as table_name,
        c.name as column_name,
        typ.name as data_type,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable
    FROM sys.tables t
    INNER JOIN sys.columns c ON t.object_id = c.object_id
    INNER JOIN sys.types typ ON c.user_type_id = typ.user_type_id
    ORDER BY t.name, c.column_id
    """
    
    try:
        cursor = sql_conn.execute(query)
        for row in cursor.fetchall():
            table_name = row[0]
            if table_name not in tables:
                tables[table_name] = []
            tables[table_name].append(row[1:])
        
        logger.info(f"Found {len(tables)} tables in SQL Server")
        return tables
    except Exception as e:
        logger.error(f"Failed to get schema information: {str(e)}")
        raise

def get_type_mapping(target_db: str) -> Dict[str, str]:
    """Get the appropriate type mapping for the target database"""
    mappings = {
        'postgres': SQL_TO_PG_TYPES,
        'sqlite': SQL_TO_SQLITE_TYPES
    }
    return mappings.get(target_db, SQL_TO_PG_TYPES)

def create_target_tables(target_conn: DatabaseConnection, schema_info: Dict[str, List[Tuple]], target_type: str):
    """Create tables in target database with appropriate schema"""
    type_mapping = get_type_mapping(target_type)
    
    try:
        # Start a single transaction for all table creation
        if isinstance(target_conn, SQLite):
            target_conn.execute("BEGIN TRANSACTION")
            
        for table_name, columns in schema_info.items():
            try:
                # Drop table if it exists to ensure clean migration
                drop_stmt = f"DROP TABLE IF EXISTS {table_name}"
                target_conn.execute(drop_stmt)
                
                create_stmt = f"CREATE TABLE {table_name} (\n"
                cols = []

                for col_info in columns:
                    col_name, data_type, max_length, precision, scale, is_nullable = col_info
                    target_type = type_mapping.get(data_type.lower(), "TEXT")
                    
                    # For SQLite, simplify the types
                    if isinstance(target_conn, SQLite):
                        if target_type.startswith(('varchar', 'char', 'nvarchar', 'nchar')):
                            target_type = 'TEXT'
                        elif target_type.startswith(('decimal', 'numeric')):
                            target_type = 'REAL'
                        elif target_type in ('bit', 'tinyint', 'smallint', 'int', 'bigint'):
                            target_type = 'INTEGER'

                    nullable = "" if is_nullable else " NOT NULL"
                    cols.append(f"{col_name} {target_type}{nullable}")

                create_stmt += ",\n".join(cols)
                create_stmt += "\n)"

                logger.info(f"Creating table {table_name}")
                target_conn.execute(create_stmt)

            except Exception as e:
                logger.error(f"Failed to create table {table_name}: {str(e)}")
                raise

        # Commit the transaction for SQLite
        if isinstance(target_conn, SQLite):
            target_conn.execute("COMMIT")
            # Set pragmas after table creation
            for pragma, value in SQLITE['pragmas'].items():
                target_conn.execute(f"PRAGMA {pragma}={value}")

    except Exception as e:
        if isinstance(target_conn, SQLite):
            target_conn.execute("ROLLBACK")
        logger.error(f"Failed to create tables: {str(e)}")
        raise

def migrate_table_data(
    source_conn: DatabaseConnection,
    target_conn: DatabaseConnection,
    table_name: str,
    columns: List[Tuple],
    batch_size: int = 1000
):
    """Migrate data for a single table with progress bar"""
    try:
        # Get row count
        count_result = source_conn.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()
        total_rows = count_result[0] if count_result else 0

        if total_rows == 0:
            logger.info(f"No data in table {table_name}")
            return

        # Prepare statements
        col_names = [col[0] for col in columns]
        select_stmt = f"SELECT {','.join(col_names)} FROM {table_name}"
        
        # Adjust placeholders based on target database type
        if isinstance(target_conn, SQLite):
            placeholders = ",".join(["?" for _ in col_names])
        else:
            placeholders = ",".join(["%s" for _ in col_names])
            
        insert_stmt = f"INSERT INTO {table_name} ({','.join(col_names)}) VALUES ({placeholders})"

        logger.info(f"Migrating {total_rows} rows from {table_name}")
        
        with tqdm(total=total_rows, desc=table_name) as pbar:
            # Start transaction
            if isinstance(target_conn, SQLite):
                target_conn.execute("BEGIN TRANSACTION")
            
            try:
                rows = source_conn.execute(select_stmt).fetchall()
                
                for i in range(0, len(rows), batch_size):
                    batch = rows[i:i + batch_size]
                    for row in batch:
                        # Convert any None values to NULL for SQLite
                        cleaned_row = tuple(None if v == '' else v for v in row)
                        target_conn.execute(insert_stmt, cleaned_row)
                    pbar.update(len(batch))
                
                if isinstance(target_conn, SQLite):
                    target_conn.execute("COMMIT")
                else:
                    target_conn.conn.commit()
                    
            except Exception as e:
                if isinstance(target_conn, SQLite):
                    target_conn.execute("ROLLBACK")
                raise e

    except Exception as e:
        logger.error(f"Failed to migrate data for table {table_name}: {str(e)}")
        raise

def verify_migration(sql_conn: SQLServer, pg_conn: PostgreSQL, table_name: str) -> bool:
    """Verify the migration of a table"""
    try:
        sql_count = sql_conn.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0]
        pg_count = pg_conn.execute(f"SELECT COUNT(*) FROM {table_name}").fetchone()[0]
        
        if sql_count != pg_count:
            logger.error(f"Count mismatch for table {table_name}: SQL={sql_count}, PG={pg_count}")
            return False
            
        logger.info(f"Verified table {table_name}: {sql_count} rows")
        return True
    except Exception as e:
        logger.error(f"Failed to verify table {table_name}: {str(e)}")
        return False

def main():
    """Main migration process"""
    source_conn = None
    target_conn = None
    
    # Get target database type from environment or default to postgres
    target_db = os.getenv("TARGET_DB", "postgres").lower()
    
    try:
        # Connect to source database (SQL Server)
        source_conn = SQLServer().connect("vpic")
        
        # Connect to target database based on type
        if target_db == "sqlite":
            target_conn = SQLite().connect(str(SQLITE["database"]))
        else:
            ensure_database("vpic", "postgres")
            target_conn = PostgreSQL().connect("vpic")

        # Get schema information
        schema_info = get_table_schema(source_conn)

        # Create tables in target database
        create_target_tables(target_conn, schema_info, target_db)

        # Migrate and verify each table
        failed_tables = []
        for table_name, columns in schema_info.items():
            try:
                migrate_table_data(source_conn, target_conn, table_name, columns)
                if not verify_migration(source_conn, target_conn, table_name):
                    failed_tables.append(table_name)
            except Exception as e:
                logger.error(f"Failed to migrate table {table_name}: {str(e)}")
                failed_tables.append(table_name)

        if failed_tables:
            logger.error(f"Migration completed with errors. Failed tables: {failed_tables}")
        else:
            logger.info("Migration completed successfully")

    except Exception as e:
        logger.error(f"Migration failed: {str(e)}")
        raise

    finally:
        if source_conn:
            source_conn.close()
        if target_conn:
            target_conn.close()

if __name__ == "__main__":
    main()