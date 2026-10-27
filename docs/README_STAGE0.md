# Stage 0: Requirements, Tech Setup and Folder Structure

## 1. Objective
Define what the system must do, choose and install the tools, and create the
project skeleton so that later stages only add code, not structure.

## 2. What we did
1. Wrote down the functional and non-functional requirements (below).
2. Fixed the tech stack: MySQL 8, Python 3, command-line menu, plain SQL, Git.
3. Created the folder structure with empty placeholder files.
4. Added `requirements.txt`, `.gitignore` and `src/config_example.py`.
5. Wrote `src/db.py`, a connection helper with a self-test.
6. Initialised the Git repository and made the first commit.

### 2.1 Functional requirements
| ID | Module | Requirement |
|----|--------|-------------|
| FR1 | Login | Warden/admin logs in with username and password |
| FR2 | Student | Add a student record |
| FR3 | Student | Display all students as a formatted table |
| FR4 | Student | Update a chosen field of a student |
| FR5 | Student | Delete a student after confirmation |
| FR6 | Student | Search by student ID or partial name (LIKE) |
| FR7 | Student | Block registration when 100 students exist |
| FR8 | Student | Block allotment when a room is full (capacity 4) |
| FR9 | Attendance | Mark Present / Absent / Leave for all students on a date |
| FR10 | Attendance | Reject a second entry for the same student and date |
| FR11 | Attendance | View records by date, by student, by month |
| FR12 | Attendance | Show attendance percentage per student |
| FR13 | Attendance | Show defaulters (below 75%) |

### 2.2 Non-functional requirements
- **Integrity:** rules enforced in the database (PK, FK, UNIQUE, CHECK, trigger), not only in Python.
- **Simplicity:** beginner-readable code, one function per operation.
- **Reliability:** invalid input gives a clear message, never a crash.
- **Scale:** at most 100 students, one admin user.

### 2.3 Validation rules
- Name must not be empty.
- Phone and guardian phone must be exactly 10 digits.
- Dates must be valid, in `YYYY-MM-DD` format.
- `student_id` must be unique.

## 3. Files created or modified
| File | Purpose |
|------|---------|
| `requirements.txt` | Python packages to install |
| `.gitignore` | Keeps cache files and the real password out of Git |
| `src/config_example.py` | Template for DB connection settings |
| `src/db.py` | `get_connection()` helper and connection test |
| `docs/README_STAGE0.md` | This file |
| Other files in `docs/`, `sql/`, `src/`, `tests/` | Empty placeholders, filled in later stages |

## 4. Technologies and tools used
| Technology | Version | Why used |
|-----------|---------|----------|
| MySQL Server | 8.0 or later | Full support for FK, CHECK, views, triggers, procedures |
| Python | 3.10 or later | Simple syntax, easy to explain |
| mysql-connector-python | 8.0 or later | Official MySQL driver, runs plain SQL |
| tabulate | 0.9 or later | Prints query results as neat tables |
| Git | any recent | Version history, one commit per stage |
| MySQL Workbench (optional) | 8.0 | Run SQL visually, draw ER diagrams |

**Why MySQL over SQLite:** SQLite has no stored procedures and only partial
`ALTER TABLE` support. MySQL lets us demonstrate triggers, procedures and views,
which are common viva topics.

**Why command line over Tkinter:** less GUI code, so the focus stays on SQL.

## 5. Key concepts covered
- Requirement analysis: functional vs non-functional requirements.
- Client-server DBMS: Python is the client, MySQL is the server.
- Separation of concerns: connection settings live in one file (`db.py`).
- Database-level integrity planned from the start.

## 6. How to run / test this stage
```bash
# 1. Install MySQL 8 and make sure the service is running
#    (Windows: MySQL Installer; Ubuntu: sudo apt install mysql-server)

# 2. Create a virtual environment and install the packages
cd hostel-management
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # Linux / macOS
pip install -r requirements.txt

# 3. Create your config file and set your MySQL password inside it
copy src\config_example.py src\config.py     # Windows
# cp src/config_example.py src/config.py     # Linux / macOS

# 4. Test the connection
cd src
python db.py

# 5. Start Git
cd ..
git init
git add .
git commit -m "Stage 0: requirements, tech setup and folder structure"
```

## 7. Output / results
Correct password:
```
Connected to MySQL server. Version: 8.0.xx
```
Wrong password or MySQL stopped:
```
Connection failed: 1045 (28000): Access denied for user 'root'@'localhost' ...
Check that MySQL is running and the password in src/config.py is correct.
```

## 8. Issues faced and fixes
| Issue | Fix |
|-------|-----|
| `ModuleNotFoundError: mysql` | Activate the venv, then `pip install -r requirements.txt` |
| `Access denied for user 'root'` | Set the correct password in `src/config.py` |
| `Can't connect to MySQL server on 'localhost'` | Start the MySQL service |
| Password would end up in Git | `config.py` is in `.gitignore`; only `config_example.py` is committed |

## 9. Next stage
**Stage 1: Database design.** ER diagram, relational schema for Student, Room,
Attendance and Admin, and a 1NF/2NF/3NF proof for each table.
