# Stage 2: Database Implementation

## 1. Objective
Turn the Stage 1 design into a working MySQL database. This covers tables with
every constraint, indexes, views, triggers and a function, loaded with sample
data that exercises every rule.

## 2. What we did
1. Wrote `schema.sql`, which drops and recreates `hostel_db` so it can be re-run safely.
2. Created 4 tables in foreign-key order: admin → room → student → attendance.
3. Added named constraints: PRIMARY KEY, FOREIGN KEY (CASCADE / RESTRICT / SET NULL), NOT NULL, UNIQUE, CHECK, DEFAULT.
4. Added 2 indexes: `student(full_name)` and `attendance(att_date)`.
5. Created 3 views: `v_attendance_summary`, `v_defaulters`, `v_room_occupancy`.
6. Created 3 triggers:
   - the 100-student limit
   - room capacity on insert
   - room capacity on update
7. Created 1 function, `fn_attendance_pct(student_id)`.
8. Wrote `seed.sql`: 1 admin, 5 rooms, 12 students, and 120 attendance rows covering 10 days.

## 3. Files created or modified
| File | Purpose |
|------|---------|
| `sql/schema.sql` | Database, tables, constraints, indexes, views, triggers, function |
| `sql/seed.sql` | Sample data for testing |
| `docs/README_STAGE2.md` | This file |

## 4. Technologies and tools used
| Technology | Version | Why used |
|-----------|---------|----------|
| MySQL Server | 8.0.44 | CHECK constraints are enforced from 8.0.16. Supports triggers, views and functions |
| MySQL Command Line Client / Workbench | 8.0 | To run the .sql scripts |
| SQL (DDL + DML) | - | CREATE, INSERT, SELECT |

## 5. Key concepts covered
| Concept | Where |
|---------|-------|
| DDL vs DML | `schema.sql` is DDL (CREATE). `seed.sql` is DML (INSERT) |
| Named constraints | `CONSTRAINT chk_student_phone CHECK (...)`. Error messages show the name |
| Referential actions | CASCADE (attendance → student), RESTRICT (student → room), SET NULL (attendance → admin) |
| CHECK with REGEXP | `phone REGEXP '^[0-9]{10}$'` means exactly 10 digits |
| Composite UNIQUE | `UNIQUE(student_id, att_date)` blocks duplicate attendance |
| Index | Faster search. `LIKE 'Ra%'` uses it, `LIKE '%vi%'` cannot |
| View | Virtual table, a stored SELECT. Percentage is always up to date and never stored |
| Trigger | Code that runs automatically BEFORE INSERT/UPDATE. Needed because a CHECK cannot count rows |
| SIGNAL SQLSTATE '45000' | Raises a custom error and cancels the operation |
| Stored function | `fn_attendance_pct(104)` returns one value and can be used inside SELECT |
| DELIMITER | Lets `;` appear inside BEGIN...END |
| Hashing | `SHA2('admin123', 256)`. The plain password is never stored |

## 6. How to run / test this stage

### Option A: MySQL Command Line Client (Start menu → "MySQL 8.0 Command Line Client")
Enter your password, then run (use forward slashes in the path):
```sql
SOURCE C:/path/to/hostel-management/sql/schema.sql;
SOURCE C:/path/to/hostel-management/sql/seed.sql;
```

### Option B: terminal (if `mysql` is on your PATH)
```bash
mysql -u root -p < sql/schema.sql
mysql -u root -p < sql/seed.sql
```

### Option C: MySQL Workbench
Use File → Open SQL Script → `schema.sql`, then click the lightning icon (Execute all).
Repeat for `seed.sql`.

To reload from scratch at any time, run `schema.sql` and then `seed.sql` again.

### Verification queries
```sql
USE hostel_db;

-- 1. Views and percentages
SELECT * FROM v_attendance_summary;
SELECT * FROM v_defaulters;
SELECT * FROM v_room_occupancy;
SELECT fn_attendance_pct(104) AS pct_104;

-- 2. Trigger test: A101 is full, so this must FAIL
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'A101','2026-10-01');

-- 3. Same student into A102 (3/4 used) must SUCCEED, then remove it
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'A102','2026-10-01');
DELETE FROM student WHERE student_id = 113;

-- 4. Duplicate attendance must FAIL
INSERT INTO attendance (student_id, att_date, status) VALUES (101,'2026-10-01','Present');

-- 5. Invalid status must FAIL
INSERT INTO attendance (student_id, att_date, status) VALUES (101,'2026-10-11','Late');

-- 6. Deleting a room that has students must FAIL (RESTRICT)
DELETE FROM room WHERE room_no = 'A101';
```
(The 100-student limit is tested in Stage 5 by inserting students 113 to 201.)

## 7. Output / results
After `seed.sql`:
```
admins | rooms | students | attendance_rows
     1 |     5 |       12 |             120
```

`SELECT * FROM v_defaulters;`
```
student_id | full_name       | room_no | total_days | present_days | attendance_pct
       104 | Pranav Shinde   | A101    |         10 |            6 |          60.00
       108 | Nikhil Chavan   | A103    |         10 |            5 |          50.00
       112 | Anjali Salunkhe | B201    |         10 |            7 |          70.00
```

`SELECT * FROM v_room_occupancy;`
```
room_no | floor | capacity | occupied | free_beds
A101    |     1 |        4 |        4 |         0
A102    |     1 |        4 |        3 |         1
A103    |     1 |        2 |        1 |         1
B201    |     2 |        4 |        4 |         0
B202    |     2 |        4 |        0 |         4
```

Expected results of the tests:
| Test | Expected result |
|------|-----------------|
| `fn_attendance_pct(104)` | `60.00` |
| Insert into full A101 | `ERROR 1644 (45000): Room A101 is full (capacity 4).` |
| Insert into A102 | `Query OK, 1 row affected` |
| Duplicate attendance | `ERROR 1062 (23000): Duplicate entry '101-2026-10-01' for key 'attendance.uq_attendance_day'` |
| Status 'Late' | `ERROR 3819 (HY000): Check constraint 'chk_attendance_status' is violated.` |
| Delete room A101 | `ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails ...` |

Remember these error numbers (1644, 1062, 3819, 1451). In Stage 3 the Python code
catches them and shows friendly messages.

Full percentage table (`v_attendance_summary`):
| ID | Present | Absent | Leave | % |
|----|---------|--------|-------|---|
| 101 | 10 | 0 | 0 | 100.00 |
| 102 | 9 | 1 | 0 | 90.00 |
| 103 | 9 | 0 | 1 | 90.00 |
| 104 | 6 | 4 | 0 | 60.00 |
| 105 | 10 | 0 | 0 | 100.00 |
| 106 | 9 | 1 | 0 | 90.00 |
| 107 | 8 | 0 | 2 | 80.00 |
| 108 | 5 | 4 | 1 | 50.00 |
| 109 | 9 | 0 | 1 | 90.00 |
| 110 | 9 | 1 | 0 | 90.00 |
| 111 | 9 | 1 | 0 | 90.00 |
| 112 | 7 | 1 | 2 | 70.00 |

## 8. Issues faced and fixes
| Issue | Fix |
|-------|-----|
| A CHECK cannot count rows (100 limit, room capacity) | BEFORE INSERT / BEFORE UPDATE triggers with SIGNAL |
| Semicolons inside a trigger end the CREATE statement early | `DELIMITER $$ ... DELIMITER ;` |
| `SELECT ... INTO` on a missing room gives a "No data" warning | Used `SET x = (SELECT ...)`, which returns NULL quietly. The FK then gives the real error |
| Creating a function fails with error 1418 when binary logging is on | Declared the function `READS SQL DATA` |
| MySQL does not allow CHECK on a column that has an FK with ON DELETE/UPDATE actions | No CHECK placed on `room_no`, `student_id` (in attendance) or `marked_by` |
| Division by zero for a student with no attendance yet | `NULLIF(COUNT(...), 0)` in the view, `IF total_days = 0` in the function |
| Backslashes in Windows paths break `SOURCE` | Use forward slashes: `C:/Users/...` |

## 9. Next stage
**Stage 3: Student Management module.** `student.py` adds, displays, updates,
deletes and searches students, validates input in Python, and turns the
database errors above into clear messages. `main.py` adds the admin login and menu.
