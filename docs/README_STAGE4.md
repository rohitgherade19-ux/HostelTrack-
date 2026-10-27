# Stage 4: Attendance Module

## 1. Objective
Build Module B. The warden marks daily attendance for all students on a date and
corrects mistakes. Records can be viewed by date, by student and by month, with
percentages and the defaulter list (below 75%). Duplicate entries for the same
day must be impossible.

## 2. What we did
1. Wrote `attendance.py` with one function per operation and an attendance menu.
2. **Register:** every student is linked to attendance through the FK. Option 1 lists students with the days marked so far.
3. **Mark:** pick a date, and the program lists only students not yet marked for that date who were admitted on or before it.
   - The warden types P / A / L for each student. Enter means Present.
   - A summary is shown and confirmed before anything is saved.
4. Saved a whole day as **one transaction**: either every row is saved, or none are.
5. **Duplicates** are blocked twice:
   - the program skips students already marked that day
   - `UNIQUE(student_id, att_date)` rejects any duplicate that still arrives
6. **Correct:** because a second entry is blocked, a mistake is fixed with an UPDATE on the existing row.
7. **Views:**
   - by date: JOIN, plus a GROUP BY status summary
   - by student: full history, with `fn_attendance_pct()`
   - by month: GROUP BY with conditional SUMs
8. **Percentage** and **defaulters** are read from the views `v_attendance_summary` and `v_defaulters`.
9. Added `execute_many()` to `db.py` and connected the menu in `main.py`. The logged-in `admin_id` is saved as `marked_by`.

## 3. Files created or modified
| File | Purpose |
|------|---------|
| `src/attendance.py` | Module B: register, mark, correct, view by date / student / month, percentage, defaulters |
| `src/db.py` | Modified: added `execute_many()` (batch insert in one transaction) |
| `src/main.py` | Modified: main menu option 2 opens the attendance menu |
| `docs/README_STAGE4.md` | This file |

## 4. Technologies and tools used
| Technology | Version | Why used |
|-----------|---------|----------|
| Python | 3.10+ | Application language |
| mysql-connector-python | 8.0+ | `executemany()` for batch insert, `%s` placeholders |
| MySQL views and function | 8.0 | `v_attendance_summary`, `v_defaulters`, `fn_attendance_pct()` from Stage 2 |
| tabulate | 0.9+ | Table output |
| datetime (built-in) | - | Date and month validation |

## 5. Key concepts covered
| Concept | Where |
|---------|-------|
| Composite UNIQUE key | `UNIQUE(student_id, att_date)` blocks duplicate attendance |
| Transaction (atomicity, the A in ACID) | `execute_many()`: a whole day is saved, or nothing is |
| COMMIT / ROLLBACK | Rollback when any row of the batch fails |
| Correlated subquery with NOT EXISTS | `get_unmarked_students()` |
| INNER JOIN vs LEFT JOIN | By date uses INNER (only marked students). Register uses LEFT (includes unmarked students) |
| GROUP BY with aggregates | COUNT, SUM, MAX, ROUND in register, day summary and monthly report |
| Conditional aggregation | `SUM(status = 'Present')` counts rows where the condition is true |
| COUNT(DISTINCT ...) | Number of working days in a month |
| Index-friendly date range | `att_date >= '2026-10-01' AND att_date < '2026-11-01'` instead of `MONTH(att_date) = 10` |
| Views | Percentages are always current and never stored (avoids an update anomaly) |
| Stored function in SELECT | `SELECT fn_attendance_pct(104)` |
| Foreign keys | `student_id` (registration) and `marked_by` (who marked it) |

### SQL used in this module
| Operation | SQL (short form) | Explanation |
|-----------|------------------|-------------|
| Register | `SELECT s.student_id, ..., COUNT(a.attendance_id), MAX(a.att_date) FROM student s LEFT JOIN attendance a ... GROUP BY ...` | Every student, with days marked and the last date |
| Already marked | `SELECT COUNT(*) FROM attendance WHERE att_date = %s` | How many entries exist for that day |
| Pending list | `SELECT ... FROM student s WHERE s.admission_date <= %s AND NOT EXISTS (SELECT 1 FROM attendance a WHERE a.student_id = s.student_id AND a.att_date = %s)` | Students still to be marked that day |
| Save day | `INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES (%s,%s,%s,%s)` with `executemany` | One row per student, in one transaction |
| Find entry | `SELECT status FROM attendance WHERE student_id = %s AND att_date = %s` | Look up by the natural key |
| Correct | `UPDATE attendance SET status = %s, marked_by = %s WHERE student_id = %s AND att_date = %s` | Change one existing entry |
| By date | `SELECT ... FROM attendance a JOIN student s ON ... WHERE a.att_date = %s` | Who was Present / Absent / Leave that day |
| Day summary | `SELECT status, COUNT(*) FROM attendance WHERE att_date = %s GROUP BY status` | Count per status |
| By student | `SELECT att_date, DAYNAME(att_date), status FROM attendance WHERE student_id = %s ORDER BY att_date DESC` | One student's history, newest first |
| Student % | `SELECT fn_attendance_pct(%s)` | Stored function from schema.sql |
| By month | `SELECT ..., COUNT(*), SUM(a.status='Present'), ... WHERE a.att_date >= %s AND a.att_date < %s GROUP BY s.student_id, s.full_name` | Monthly report per student |
| Working days | `SELECT COUNT(DISTINCT att_date) FROM attendance WHERE att_date >= %s AND att_date < %s` | Days on which attendance was taken |
| Percentage | `SELECT ... FROM v_attendance_summary` | All students, from the view |
| Defaulters | `SELECT ... FROM v_defaulters ORDER BY attendance_pct` | Below 75%, lowest first |

## 6. How to run / test this stage
```bash
# Clean database first (MySQL Command Line Client):
#   SOURCE C:/your/path/hostel-management/sql/schema.sql;
#   SOURCE C:/your/path/hostel-management/sql/seed.sql;
cd hostel-management/src
python main.py          # login: warden / admin123, then choose 2. Attendance
```

Manual test script:
| # | Option | Input | Expected |
|---|--------|-------|----------|
| 1 | 8 Defaulters | - | 108 (50.00), 104 (60.00), 112 (70.00) |
| 2 | 1 Register | - | 12 students, each with 10 days, last marked 2026-10-10 |
| 3 | 2 Mark | `2026-10-01` | `already marked for all 12 student(s). Duplicate entries are not allowed.` |
| 4 | 2 Mark | a future date | `cannot be marked or viewed for a future date` |
| 5 | 2 Mark | `2026-02-30` | `Invalid date` |
| 6 | 2 Mark | `2026-10-11`, type `x` once | `Type P, A or L`, then it asks again |
| 7 | 2 Mark | `2026-10-11`, finish, `Y` | `Attendance saved for 12 student(s) on 2026-10-11.` |
| 8 | 2 Mark | `2026-10-11` again | `already marked for all 12` |
| 9 | 4 By date | `2026-10-11` | 12 rows and `Day summary: ...` |
| 10 | 5 By student | `104` | 11 rows, newest first, percentage with `(DEFAULTER)` if below 75 |
| 11 | 6 By month | `2026-10` | One row per student and `Working days ... : 11` |
| 12 | 3 Correct | `104`, `2026-10-02`, `P` | `Updated: Absent -> Present` |
| 13 | 3 Correct | `104`, `2026-10-02`, `P` again | `Same as the current status. Nothing changed.` |
| 14 | 3 Correct | `104`, a date never marked | `No attendance entry ... Mark it first.` |

Extra check in MySQL after test 7 (should return 0 rows, proving there are no duplicates):
```sql
SELECT student_id, att_date, COUNT(*) FROM attendance
GROUP BY student_id, att_date HAVING COUNT(*) > 1;
```

## 7. Output / results
Marking a day:
```
--- Mark Daily Attendance ---
Date (YYYY-MM-DD, Enter = today): 2026-10-11

Marking Sunday, 11 Oct 2026
Type P = Present, A = Absent, L = Leave.  Press Enter for Present.

  [A101] 101 Ravi Patil          :
  [A101] 102 Amit Kale           : a
  [A101] 103 Sagar Jadhav        : l
  [A101] 104 Pranav Shinde       : x
    -> Type P, A or L (or Enter for Present).
  ...
Summary: Present 8, Absent 3, Leave 1  (total 12)
Save this attendance? (Y/N): Y
Attendance saved for 12 student(s) on 2026-10-11.
```
Defaulter list on the fresh seed data:
```
|   ID | Name            | Room   |   Days |   Present |   Pct |
|------|-----------------|--------|--------|-----------|-------|
|  108 | Nikhil Chavan   | A103   |     10 |         5 | 50.00 |
|  104 | Pranav Shinde   | A101   |     10 |         6 | 60.00 |
|  112 | Anjali Salunkhe | B201   |     10 |         7 | 70.00 |
(3 row(s))
```
By student (104, on seed data):
```
Student: 104 Pranav Shinde
| Date       | Day       | Status   |
|------------|-----------|----------|
| 2026-10-10 | Saturday  | Present  |
| 2026-10-09 | Friday    | Absent   |
...
Attendance percentage: 60.00%  (DEFAULTER)
```

## 8. Issues faced and fixes
| Issue | Fix |
|-------|-----|
| Marking 100 students one by one is slow | Enter means Present, so only absentees need a key |
| A crash halfway through marking would leave half a day saved | One transaction via `executemany`. Any failure rolls back the whole day |
| Duplicate blocked, but then how do you fix a typo? | Separate "Correct an entry" option that uses UPDATE |
| Students admitted later were shown for earlier dates | `WHERE admission_date <= att_date` in the pending list |
| `MONTH(att_date) = 10` cannot use the index on `att_date` | Used a date range `>= first day AND < first day of next month` |
| A `%` sign as a column alias can clash with `%s` placeholders | Column named `Pct` instead of `%` |
| Division by zero for a student with no attendance yet | `NULLIF` in the view, `IF total_days = 0` in the function |
| Correcting to the same status printed `Present -> Present` | Now prints `Nothing changed` |

## 9. Next stage
**Stage 5: Testing and sample queries.** `sql/queries.sql` with JOIN, GROUP BY,
HAVING, aggregates, subqueries and views, each with expected output. Edge cases:
student number 101 (the trigger), duplicate attendance, invalid values and cascade
delete. All test cases recorded in `tests/test_cases.md` (expected vs actual).
