


#!/usr/bin/env python3
import psycopg2
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

try:
    conn = psycopg2.connect(
        dbname="vpic",
        user="postgres",
        password="postgres",
        host="localhost",  # Use container name
        port="5432"
    )
    
    cur = conn.cursor()
    cur.execute('SELECT version()')
    ver = cur.fetchone()
    print(f"Connected to: {ver[0]}")
    
    cur.close()
    conn.close()
    
except Exception as e:
    print(f"Error: {str(e)}")