# Stage 3: Student Management Module

## 1. Objective
Build Module A: a warden logs in and can add, display, update, delete and search
students. Every rule is checked in Python for a clear message, and again by MySQL
as the final safety net.

## 2. What we did
1. Added query helpers to `db.py`: `fetch_all()`, `fetch_one()`, `execute()` (commit/rollback) and `friendly_error()`.
2. Wrote `student.py` with one function per operation.
3. Added input validators: name, phone, date, gender, year, student ID.
4. Enforced the 100-student limit before asking for any details.
5. Showed rooms with free beds (from `v_room_occupancy`) when adding or moving a student.
6. Made update safe: the warden picks a field number, and column names come from a whitelist.
7. Made delete safe: it shows the record and the count of attendance rows that CASCADE will remove, and needs `YES` to confirm.
8. Added search by ID (exact) and by name (partial, `LIKE '%text%'`).
9. Wrote `main.py`: login with 3 attempts and SHA-256 hash comparison, then the main menu.
10. Tested every menu path, including all error cases.

## 3. Files created or modified
| File | Purpose |
|------|---------|
| `src/db.py` | Modified: added query helpers and error-code to message mapping |
| `src/student.py` | Module A: validation, add, display, update, delete, search, menu |
| `src/main.py` | Login and main menu (entry point) |
| `docs/README_STAGE3.md` | This file |

## 4. Technologies and tools used
| Technology | Version | Why used |
|-----------|---------|----------|
| Python | 3.10+ | Application language |
| mysql-connector-python | 8.0+ | Sends SQL to MySQL, with `%s` placeholders |
| tabulate | 0.9+ | Prints results as tables |
| hashlib (built-in) | - | SHA-256 password hashing, same result as MySQL `SHA2(..., 256)` |
| getpass (built-in) | - | Hides the password while typing |
| datetime (built-in) | - | Real date validation (`strptime` rejects 2005-02-30) |

## 5. Key concepts covered
| Concept | Where in code |
|---------|---------------|
| CRUD (Create, Read, Update, Delete) | `add_student`, `display_all_students`, `update_student`, `delete_student` |
| Parameterized queries (prevent SQL injection) | Every query uses `%s`. Values are never joined into the SQL text |
| Whitelisting identifiers | `UPDATABLE_FIELDS`: column names cannot be `%s`, so only known names are allowed |
| Transactions: COMMIT / ROLLBACK | `db.execute()` |
| Pattern matching | `LIKE %s` with value `'%avi%'` |
| Derived attribute at query time | `TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS Age` |
| Using a view from code | `v_room_occupancy` in `show_available_rooms()` |
| Two-layer validation | Python checks first. CHECK, UNIQUE and triggers are the backup |
| Handling DB errors by code | 1644 trigger, 1062 duplicate, 3819 check, 1452 missing FK parent, 1451 FK child exists |
| ON DELETE CASCADE in action | Deleting a student removes their attendance rows |
| Password hashing | Only the hash is stored and compared |

### SQL used in this module (with one-line explanations)
| Operation | SQL | Explanation |
|-----------|-----|-------------|
| Count | `SELECT COUNT(*) FROM student` | Number of students, for the 100 limit |
| Exists | `SELECT 1 FROM student WHERE student_id = %s` | Returns a row only if that ID is taken |
| Free rooms | `SELECT ... FROM v_room_occupancy WHERE free_beds > 0` | Rooms that still have a bed |
| Add | `INSERT INTO student (...) VALUES (%s, ...)` | Insert one row. Triggers check limit and capacity |
| Display | `SELECT ..., TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS Age ... ORDER BY student_id` | All students, age computed live |
| Details | `SELECT * FROM student WHERE student_id = %s` | One student by primary key |
| Update | `UPDATE student SET <column> = %s WHERE student_id = %s` | Change one field of one student |
| Delete | `DELETE FROM student WHERE student_id = %s` | Remove a student. CASCADE removes their attendance |
| Cascade count | `SELECT COUNT(*) FROM attendance WHERE student_id = %s` | Shown before delete as a warning |
| Name search | `SELECT ... WHERE full_name LIKE %s ORDER BY full_name` | Partial match anywhere in the name |
| Login | `SELECT admin_id, full_name FROM admin WHERE username = %s AND password_hash = %s` | Matches the username and the password hash |

## 6. How to run / test this stage
```bash
# Start from a clean database (in MySQL Command Line Client):
#   SOURCE C:/your/path/hostel-management/sql/schema.sql;
#   SOURCE C:/your/path/hostel-management/sql/seed.sql;

cd hostel-management/src
python main.py
```
Login: `warden` / `admin123`

Manual test script:
| # | Action | Input | Expected |
|---|--------|-------|----------|
| 1 | Login | wrong password, then correct | `Attempts left: 2`, then `Welcome, Hostel Warden!` |
| 2 | Add | ID `101` | `Student ID 101 already exists` |
| 3 | Add | name of spaces only | `Full name cannot be empty.` |
| 4 | Add | DOB `2005-02-30` | `must be a valid date` |
| 5 | Add | phone `12345` | `must be exactly 10 digits` |
| 6 | Add | room `A101` | `does not exist or is full` |
| 7 | Add | admission date before DOB | `Admission date must be after date of birth.` |
| 8 | Add | ID 113, valid data, room A102 | `Student 113 (...) added to room A102.` |
| 9 | Search by name | `avi` | Ravi Patil |
| 10 | Search by ID | `999` | `No student with ID 999.` |
| 11 | Update room of 113 | `B201` (full) | `Could not update: Room B201 is full (capacity 4).` (from trigger) |
| 12 | Update room of 113 | `A103` | `Room number updated` |
| 13 | Update phone of 113 | `9876500101` (Ravi's) | `Duplicate value ...` (UNIQUE) |
| 14 | Delete 104 | `YES` | `will also delete 10 attendance record(s)`, then `deleted` |
| 15 | Delete 101 | `no` | `Delete cancelled.` |

## 7. Output / results
Adding a student:
```
--- Add New Student ---
Students currently registered: 12/100

Rooms with free beds:
| room_no   |   floor |   capacity |   occupied |   free_beds |
|-----------|---------|------------|------------|-------------|
| A102      |       1 |          4 |          3 |           1 |
| A103      |       1 |          2 |          1 |           1 |
| B202      |       2 |          4 |          0 |           4 |
Student ID: 101
  -> Student ID 101 already exists. Choose another.
...
Student 113 (Test Student) added to room A102.
```
Name search for `avi`:
```
|   ID | Name       |      Phone | Course      | Room   |
|------|------------|------------|-------------|--------|
|  101 | Ravi Patil | 9876500101 | B.Tech AIML | A101   |
(1 record(s))
```
At 100 students:
```
--- Add New Student ---
Registration blocked: the hostel already has 100 students.
```

## 8. Issues faced and fixes
| Issue | Fix |
|-------|-----|
| Column names cannot be passed as `%s` in UPDATE | Whitelist dictionary `UPDATABLE_FIELDS`, so only known names reach the SQL |
| Python `date.today()` vs the MySQL server date | Both run on the same PC here. Python checks "not in future" |
| Wide single-student row hard to read | Printed as a two-column Field / Value table |
| Trigger errors arrive as a generic `DatabaseError` | `friendly_error()` reads `e.errno` (1644) and shows the trigger's own message |
| `getpass` warning in some IDE consoles (password visible) | Run from a normal terminal / Command Prompt |
| Changes lost if an error happens midway | `execute()` commits on success and rolls back on error |
| Deleting a student silently removes attendance | The count is shown first, and the warden must type `YES` |

## 9. Next stage
**Stage 4: Attendance module.** `attendance.py` marks daily attendance for all
students on a date, blocks duplicates, shows records by date, student or month,
shows percentages from `v_attendance_summary`, and lists defaulters.
