# #!/usr/bin/env python3
# import psycopg2
# import logging

# logging.basicConfig(level=logging.INFO)
# logger = logging.getLogger(__name__)

# def test_connection():
#     try:
#         # Try connecting to postgres database first
#         conn = psycopg2.connect(
#             dbname="postgres",
#             user="postgres",
#             password="postgres",
#             host="localhost",
#             port="5432"
#         )
        
#         logger.info("Successfully connected to postgres database")
        
#         # Test query
#         cur = conn.cursor()
#         cur.execute("SELECT current_database(), current_user")
#         result = cur.fetchone()
#         logger.info(f"Current database: {result[0]}, Current user: {result[1]}")
        
#         cur.close()
#         conn.close()
        
#         # Now try connecting to vpic database
#         conn = psycopg2.connect(
#             dbname="vpic",
#             user="postgres",
#             password="postgres",
#             host="localhost",
#             port="5432"
#         )
        
#         logger.info("Successfully connected to vpic database")
        
#         cur = conn.cursor()
#         cur.execute("SELECT current_database(), current_user")
#         result = cur.fetchone()
#         logger.info(f"Current database: {result[0]}, Current user: {result[1]}")
        
#         cur.close()
#         conn.close()
        
#     except psycopg2.Error as e:
#         logger.error(f"Connection failed: {str(e)}")
#         logger.error(f"Error code: {e.pgcode}")
#         logger.error(f"Error message: {e.pgerror}")

# if __name__ == "__main__":
#     test_connection()


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