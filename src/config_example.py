"""
config_example.py
-----------------
Copy this file to config.py and put your own MySQL password in it.
config.py is listed in .gitignore, so your password never goes to Git.
"""

DB_CONFIG = {
    "host": "localhost",      # MySQL server runs on this computer
    "port": 3306,             # default MySQL port
    "user": "root",           # MySQL username
    "password": "Rohit@123",
    "database": "hostel_db",  # created in Stage 2 by schema.sql
}
