"""
db.py
-----
Connection helper. Every other module (student.py, attendance.py) imports
from here, so connection settings and query code live in ONE place.

Stage 0: get_connection(), test_connection()
Stage 3: fetch_all(), fetch_one(), execute(), friendly_error()
Stage 4: execute_many()
"""

import mysql.connector
from mysql.connector import Error

try:
    from config import DB_CONFIG          # your real settings (not in Git)
except ImportError:
    from config_example import DB_CONFIG  # fallback so the import never crashes


def get_connection(use_database=True):
    """
    Open and return a MySQL connection.
    use_database=False connects to the server only (needed before
    hostel_db exists, i.e. during Stage 0 and when running schema.sql).
    """
    settings = dict(DB_CONFIG)
    if not use_database:
        settings.pop("database", None)
    return mysql.connector.connect(**settings)


def test_connection():
    """Stage 0 check: can Python reach the MySQL server?"""
    try:
        conn = get_connection(use_database=False)
        cur = conn.cursor()
        cur.execute("SELECT VERSION()")   # asks MySQL for its version number
        version = cur.fetchone()[0]
        print(f"Connected to MySQL server. Version: {version}")
        cur.close()
        conn.close()
        return True
    except Error as e:
        print(f"Connection failed: {e}")
        print("Check that MySQL is running and the password in src/config.py is correct.")
        return False


# ---------------------------------------------------------------------
# Query helpers (added in Stage 3)
#
# All SQL in this project uses %s placeholders, e.g.
#     fetch_one("SELECT * FROM student WHERE student_id = %s", (101,))
# The driver sends the value separately from the SQL text, so user input
# can never change the query. This prevents SQL injection.
# ---------------------------------------------------------------------

def fetch_all(sql, params=()):
    """Run a SELECT and return (column_names, list_of_rows)."""
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        rows = cur.fetchall()
        columns = [col[0] for col in cur.description]
        cur.close()
        return columns, rows
    finally:
        conn.close()                      # always close, even after an error


def fetch_one(sql, params=()):
    """Run a SELECT and return the first row only (or None if no row)."""
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        row = cur.fetchone()
        cur.fetchall()                    # clear any remaining rows
        cur.close()
        return row
    finally:
        conn.close()


def execute(sql, params=()):
    """
    Run an INSERT / UPDATE / DELETE, COMMIT it, and return the number of
    rows affected. On error the change is rolled back and the error is
    passed up to the caller (which shows a friendly message).
    """
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        conn.commit()                     # make the change permanent
        count = cur.rowcount
        cur.close()
        return count
    except Error:
        conn.rollback()                   # undo the half-done change
        raise
    finally:
        conn.close()


def execute_many(sql, list_of_params):
    """
    Run the same INSERT for many rows as ONE transaction (added in Stage 4).
    Either every row is saved (COMMIT) or, if any row fails, none are
    (ROLLBACK). Used to save a whole day's attendance at once.
    """
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.executemany(sql, list_of_params)
        conn.commit()
        count = cur.rowcount
        cur.close()
        return count
    except Error:
        conn.rollback()
        raise
    finally:
        conn.close()


def friendly_error(e):
    """
    Turn a MySQL error into a message a warden can understand.
    The numbers are MySQL error codes we saw in Stage 2 testing.
    """
    code = getattr(e, "errno", None)
    if code == 1644:      # SIGNAL from our triggers (hostel full / room full)
        return e.msg
    if code == 1062:      # UNIQUE or PRIMARY KEY violated
        return "Duplicate value: this ID / phone / attendance entry already exists."
    if code == 3819:      # CHECK constraint violated
        return f"Invalid value rejected by the database ({e.msg})."
    if code == 1452:      # child row points to a parent that does not exist
        return "Linked record not found (for example, that room number does not exist)."
    if code == 1451:      # parent row still has child rows (RESTRICT)
        return "Cannot delete: other records depend on this one."
    return f"Database error {code}: {e.msg if hasattr(e, 'msg') else e}"


# Run "python db.py" to test the connection on its own.
if __name__ == "__main__":
    test_connection()