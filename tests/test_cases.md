# Test Cases: Government Hostel Management System

**How to use this file:** run each test, then copy what you actually saw into the
**Actual** column and write **Pass** or **Fail** in **Result**. A test passes when
Actual matches Expected. All expected values assume a fresh database
(`schema.sql` followed by `seed.sql`).

| Part | What is tested | How it is run |
|------|----------------|---------------|
| A | Database rules (constraints, triggers, referential actions) | `SOURCE D:/hostel-management/tests/edge_cases.sql;` |
| B | Student Management module (Python) | `python main.py` → 1 |
| C | Attendance module (Python) | `python main.py` → 2 |
| D | Sample queries | `sql/queries.sql`, one query at a time |

Tester: ____________  Date: ____________  MySQL version: 8.0.44

---

## Part A: Database-level tests (`tests/edge_cases.sql`)

| ID | Rule tested | Input | Expected | Actual | Result |
|----|-------------|-------|----------|--------|--------|
| E1 | Room capacity on insert (trigger) | New student into A101 (4/4) | `ERROR 1644: Room A101 is full (capacity 4).` | | |
| E2 | Room capacity on update (trigger) | Move 105 to B201 (4/4) | `ERROR 1644: Room B201 is full (capacity 4).` | | |
| E3 | Primary key | student_id 101 again | `ERROR 1062: Duplicate entry '101' for key 'student.PRIMARY'` | | |
| E4 | UNIQUE phone | Phone 9876500101 again | `ERROR 1062: Duplicate entry '9876500101' ... 'student.uq_student_phone'` | | |
| E5 | CHECK phone | Phone `12345` | `ERROR 3819: Check constraint 'chk_student_phone' is violated.` | | |
| E6 | CHECK name | Name of spaces only | `ERROR 3819: ... 'chk_student_name' ...` | | |
| E7 | Valid date | DOB `2005-02-30` | `ERROR 1292: Incorrect date value: '2005-02-30' ...` | | |
| E8 | CHECK gender | Gender `X` | `ERROR 3819: ... 'chk_student_gender' ...` | | |
| E9 | CHECK year | Year 7 | `ERROR 3819: ... 'chk_student_year' ...` | | |
| E10 | CHECK admission after DOB | Admission 2004, DOB 2005 | `ERROR 3819: ... 'chk_admission_after_dob' ...` | | |
| E11 | FK student → room | Room `Z999` | `ERROR 1452: Cannot add or update a child row ...` | | |
| E12 | Valid insert | Student 113 into B202 | `Query OK, 1 row affected`, then deleted | | |
| E13 | Duplicate attendance (UNIQUE) | 101 on 2026-10-01 again | `ERROR 1062: Duplicate entry '101-2026-10-01' ... 'attendance.uq_attendance_day'` | | |
| E14 | CHECK status | Status `Late` | `ERROR 3819: ... 'chk_attendance_status' ...` | | |
| E15 | FK attendance → student | Student 999 | `ERROR 1452: Cannot add or update a child row ...` | | |
| E16 | CHECK room capacity | Capacity 6 | `ERROR 3819: ... 'chk_room_capacity' ...` | | |
| E17 | ON DELETE RESTRICT | Delete room A101 | `ERROR 1451: Cannot delete or update a parent row ...` | | |
| E18 | ON DELETE CASCADE + ROLLBACK | Delete 112 inside a transaction | Counts: 10 → 0 → 10 after ROLLBACK | | |
| E19 | ON DELETE SET NULL | Delete an admin who marked an entry | Row kept, `marked_by = NULL` | | |
| E20 | RESTRICT allows an empty room | Delete B202 inside a transaction | `1 row affected`, rolled back | | |
| E21 | **100-student limit (student no. 101)** | Fill to 100, insert one more | Count 100, then `ERROR 1644: Hostel is full: maximum 100 students allowed.`, count still 100, cleanup back to 12 | | |

---

## Part B: Student Management module (`python main.py` → 1)

| ID | Function | Input | Expected | Actual | Result |
|----|----------|-------|----------|--------|--------|
| S1 | Login | Wrong password | `Wrong username or password. Attempts left: 2` | | |
| S2 | Login | `warden` / `admin123` | `Welcome, Hostel Warden!` | | |
| S3 | Login | 3 wrong attempts | `Too many failed attempts. Exiting.` | | |
| S4 | Add: duplicate ID | ID `101` | `Student ID 101 already exists. Choose another.` | | |
| S5 | Add: non-numeric ID | `abc` | `Student ID must be a positive whole number.` | | |
| S6 | Add: blank name | spaces only | `Full name cannot be empty.` | | |
| S7 | Add: gender | `X` | `Gender must be M, F or O.` | | |
| S8 | Add: invalid date | `2005-02-30` | `... must be a valid date in YYYY-MM-DD format.` | | |
| S9 | Add: future date | e.g. `2030-01-01` | `... cannot be in the future.` | | |
| S10 | Add: phone | `12345` | `Phone number must be exactly 10 digits.` | | |
| S11 | Add: year | `7` | `Year of study must be a number from 1 to 5.` | | |
| S12 | Add: full room | `A101` | `Room A101 does not exist or is full. Pick from the list above.` | | |
| S13 | Add: admission before DOB | admission < DOB | `Admission date must be after date of birth.` | | |
| S14 | Add: valid | ID 113, room A102 | `Student 113 (...) added to room A102.` | | |
| S15 | Add: at 100 students | after running E21 setup | `Registration blocked: the hostel already has 100 students.` | | |
| S16 | Display all | - | Table of all students with computed Age, count shown | | |
| S17 | Search by name | `avi` | 1 row: 101 Ravi Patil | | |
| S18 | Search by ID | `999` | `No student with ID 999.` | | |
| S19 | Update: room to full room | 113 → `B201` | `Could not update: Room B201 is full (capacity 4).` | | |
| S20 | Update: room | 113 → `A103` | `Room number updated for student 113.` | | |
| S21 | Update: duplicate phone | 113 → `9876500101` | `Could not update: Duplicate value ...` | | |
| S22 | Update: invalid choice | `99` | `Invalid choice. Nothing changed.` | | |
| S23 | Delete: cancel | 101, type `no` | `Delete cancelled.` | | |
| S24 | Delete: confirm | 113, type `YES` | `will also delete 0 attendance record(s)`, then `Student 113 deleted.` | | |

Run S15 last (after S24 has deleted student 113). For S15, run only Part E of `edge_cases.sql` up to `SELECT COUNT(*) AS total_students` (100), test
in Python, then run the cleanup lines.

---

## Part C: Attendance module (`python main.py` → 2)

Order matters: A11, A13, A15 and A16 expect the fresh seed (10 days). Either run them
before A6, or reload `seed.sql` first. After A6 there are 11 days, so the percentages change.

| ID | Function | Input | Expected | Actual | Result |
|----|----------|-------|----------|--------|--------|
| A1 | Register | - | 12 students, 10 days each, last marked 2026-10-10 | | |
| A2 | Mark: already marked | `2026-10-01` | `already marked for all 12 student(s). Duplicate entries are not allowed.` | | |
| A3 | Mark: future date | tomorrow's date | `Attendance cannot be marked or viewed for a future date.` | | |
| A4 | Mark: invalid date | `2026-02-30` | `Invalid date. Use YYYY-MM-DD ...` | | |
| A5 | Mark: wrong key | `x` | `Type P, A or L (or Enter for Present).` and asks again | | |
| A6 | Mark: save | `2026-10-11`, then `Y` | `Attendance saved for 12 student(s) on 2026-10-11.` | | |
| A7 | Mark: cancel | `2026-10-12`, then `N` | `Not saved.` (no rows for 2026-10-12) | | |
| A8 | Mark: same date again | `2026-10-11` | `already marked for all 12` | | |
| A9 | View by date | `2026-10-11` | 12 rows and `Day summary: ...` | | |
| A10 | View by date: none | `2026-09-01` | `No attendance marked for 2026-09-01.` | | |
| A11 | View by student | `104` (fresh seed) | 10 rows newest first, `Attendance percentage: 60.00%  (DEFAULTER)` | | |
| A12 | View by student: unknown | `999` | `No student with ID 999.` | | |
| A13 | View by month | `2026-10` | 12 rows, `Working days with attendance this month: 10` (fresh seed) | | |
| A14 | View by month: empty | `2026-09` | `No attendance marked in this month.` | | |
| A15 | Percentages | - | Same as `v_attendance_summary` (101 = 100.00 ... 108 = 50.00) | | |
| A16 | Defaulters | - (fresh seed) | 108 (50.00), 104 (60.00), 112 (70.00) | | |
| A17 | Correct entry | 104, `2026-10-02`, `P` | `Updated: Absent -> Present` | | |
| A18 | Correct: same status | 104, `2026-10-02`, `P` again | `Same as the current status. Nothing changed.` | | |
| A19 | Correct: no entry | 104, `2026-09-01` | `No attendance entry ... Mark it first.` | | |
| A20 | Defaulter list changes | after A17 | 104 now 70.00, still a defaulter | | |

---

## Part D: Sample queries (`sql/queries.sql`)

| ID | Concept | Expected (fresh seed) | Actual | Result |
|----|---------|-----------------------|--------|--------|
| Q1 | INNER JOIN | 12 rows, 101 Ravi Patil / A101 / floor 1 first | | |
| Q2 | LEFT JOIN | 5 rooms, B202 shows 0 | | |
| Q3 | GROUP BY | AIML 3, CSE 3, Civil 2, ENTC 2, Electrical 1, Mech 1 | | |
| Q4 | GROUP BY | F 4, M 8 / years 1:3, 2:4, 3:3, 4:2 | | |
| Q5 | Aggregates | 12, 50.00, 100.00, 83.33 | | |
| Q6 | HAVING | A101, B201 | | |
| Q7 | Scalar subquery | 8 students above 83.33 | | |
| Q8 | IN subquery | 104, 108 | | |
| Q9 | NOT EXISTS (correlated) | 101, 103, 105, 107, 109 | | |
| Q10 | Date-wise GROUP BY | 10 days, 07 Oct = 12 present (100.00) | | |
| Q11 | GROUP BY on view | A103 50.00, A101 85.00, B201 85.00, A102 90.00 | | |
| Q12 | ORDER BY + LIMIT | 101, 105, 102 | | |
| Q13 | View + JOIN | 108, 104, 112 with guardian phones | | |
| Q14 | JOIN + HAVING | 107, 112 (2 leave days each) | | |
| Q15 | MIN subquery + derived age | 107 Vishal Gaikwad, 2003-09-25, age 23 | | |
| Q16 | Views | 12 / 3 / 5 rows | | |
| Q17 | Stored function | 100.00, 60.00, 50.00 | | |
| Q18 | Metadata / EXPLAIN | 3 triggers. `'%vi%'` has no possible key | | |

---

## Summary

| Part | Total | Passed | Failed |
|------|-------|--------|--------|
| A: Database rules | 21 | | |
| B: Student module | 24 | | |
| C: Attendance module | 20 | | |
| D: Queries | 18 | | |
| **Total** | **83** | | |