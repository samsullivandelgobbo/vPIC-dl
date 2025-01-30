#!/usr/bin/env python3
import psycopg2
import logging
from config.settings import POSTGRES

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_connection():
    try:
        logger.info("Testing PostgreSQL connection with settings:")
        logger.info(f"Host: {POSTGRES['host']}")
        logger.info(f"Port: {POSTGRES['port']}")
        logger.info(f"Database: {POSTGRES['dbname']}")
        logger.info(f"User: {POSTGRES['user']}")
        
        conn = psycopg2.connect(**POSTGRES)
        cur = conn.cursor()
        
        # Test basic query
        cur.execute('SELECT version()')
        version = cur.fetchone()[0]
        logger.info(f"Connected successfully to PostgreSQL: {version}")
        
        # Test user permissions
        cur.execute('SELECT current_user, session_user')
        users = cur.fetchone()
        logger.info(f"Current user: {users[0]}, Session user: {users[1]}")
        
        cur.close()
        conn.close()
        return True
        
    except Exception as e:
        logger.error(f"Connection failed: {str(e)}")
        return False

if __name__ == "__main__":
    test_connection()
