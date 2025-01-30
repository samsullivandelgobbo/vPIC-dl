# scripts/utils/database.py
import pyodbc
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
import sqlite3
from abc import ABC, abstractmethod
from typing import Any, Optional, Dict
import logging

logger = logging.getLogger(__name__)

class DatabaseConnection(ABC):
    """Abstract base class for database connections"""
    
    def __init__(self):
        self.conn = None
        self.cur = None
        
    @abstractmethod
    def connect(self, database: str, **kwargs) -> 'DatabaseConnection':
        pass
        
    @abstractmethod
    def execute(self, query: str, params: Optional[tuple] = None) -> Any:
        pass
        
    def close(self):
        if self.cur:
            self.cur.close()
        if self.conn:
            self.conn.close()
            
    def __enter__(self):
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

class SQLServer(DatabaseConnection):
    """SQL Server connection manager"""
    def connect(self, database: str = "master", **kwargs) -> 'SQLServer':
        try:
            # Import settings here to avoid circular imports
            from vpic_migration.settings import SQL_SERVER
            
            # Use settings with override from kwargs
            conn_str = (
                f"DRIVER={{{kwargs.get('driver', SQL_SERVER['driver'])}}};"
                f"SERVER={kwargs.get('server', SQL_SERVER['server'])};"
                f"DATABASE={database};"
                f"UID={kwargs.get('user', SQL_SERVER['user'])};"
                f"PWD={kwargs.get('password', SQL_SERVER['password'])};"
                f"TrustServerCertificate={kwargs.get('trust_cert', SQL_SERVER['trust_cert'])};"
            )
            
            self.conn = pyodbc.connect(conn_str)
            self.cur = self.conn.cursor()
            logger.info(f"Connected to SQL Server - {database}")
            return self
        except pyodbc.Error as e:
            logger.error(f"SQL Server connection failed: {str(e)}")
            raise

    def execute(self, query: str, params: Optional[tuple] = None) -> Any:
        try:
            if params:
                self.cur.execute(query, params)
            else:
                self.cur.execute(query)
            return self.cur
        except pyodbc.Error as e:
            logger.error(f"SQL Server query failed: {str(e)}")
            raise

class PostgreSQL(DatabaseConnection):
    """PostgreSQL connection manager"""
    def connect(self, database: str, **kwargs) -> 'PostgreSQL':
        try:
            params = {
                'dbname': database,
                'user': kwargs.get('user', 'postgres'),
                'password': kwargs.get('password', 'postgres'),
                'host': kwargs.get('host', 'localhost'),
                'port': kwargs.get('port', 5432)
            }
            
            logger.info(f"Connecting to PostgreSQL - {database}")
            self.conn = psycopg2.connect(**params)
            self.cur = self.conn.cursor()
            return self
        except psycopg2.Error as e:
            logger.error(f"PostgreSQL connection failed: {str(e)}")
            raise

    def execute(self, query: str, params: Optional[tuple] = None) -> Any:
        try:
            if params:
                self.cur.execute(query, params)
            else:
                self.cur.execute(query)
            return self.cur
        except psycopg2.Error as e:
            logger.error(f"PostgreSQL query failed: {str(e)}")
            raise

class SQLite(DatabaseConnection):
    """SQLite connection manager"""
    def connect(self, database: str, **kwargs) -> 'SQLite':
        try:
            self.conn = sqlite3.connect(database)
            self.conn.execute("PRAGMA foreign_keys = OFF")  # Temporarily disable foreign key constraints
            self.conn.execute("PRAGMA journal_mode = WAL")  # Use WAL mode for better performance
            self.conn.execute("PRAGMA synchronous = NORMAL")  # Reduce synchronous mode for better performance
            self.cur = self.conn.cursor()
            logger.info(f"Connected to SQLite - {database}")
            return self
        except sqlite3.Error as e:
            logger.error(f"SQLite connection failed: {str(e)}")
            raise

    def execute(self, query: str, params: Optional[tuple] = None) -> Any:
        try:
            if params:
                self.cur.execute(query, params)
            else:
                self.cur.execute(query)
            return self.cur
        except sqlite3.Error as e:
            logger.error(f"SQLite query failed: {str(e)}")
            logger.error(f"Query: {query}")
            if params:
                logger.error(f"Parameters: {params}")
            raise

def get_connection(db_type: str) -> DatabaseConnection:
    """Factory function to get appropriate database connection"""
    connections = {
        'sqlserver': SQLServer,
        'postgres': PostgreSQL,
        'sqlite': SQLite
    }
    
    if db_type not in connections:
        raise ValueError(f"Unsupported database type: {db_type}")
        
    return connections[db_type]()

def ensure_database(name, server_type="postgres"):
    """Ensure database exists and is accessible"""
    if server_type == "postgres":
        db = PostgreSQL()
        with db.connect(name) as conn:
            conn.conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
            try:
                conn.execute(f"SELECT 1 FROM pg_database WHERE datname = '{name}'")
                if not conn.cur.fetchone():
                    conn.execute(f"CREATE DATABASE {name}")
                    logger.info(f"Created PostgreSQL database: {name}")
                else:
                    logger.info(f"PostgreSQL database already exists: {name}")
            except psycopg2.Error as e:
                logger.error(f"PostgreSQL database creation failed: {str(e)}")
                raise
    else:
        db = SQLServer()
        with db.connect() as conn:
            try:
                conn.execute(f"SELECT database_id FROM sys.databases WHERE name = '{name}'")
                if not conn.cur.fetchone():
                    conn.execute(f"CREATE DATABASE {name}")
                    logger.info(f"Created SQL Server database: {name}")
                else:
                    logger.info(f"SQL Server database already exists: {name}")
            except pyodbc.Error as e:
                logger.error(f"SQL Server database creation failed: {str(e)}")
                raise