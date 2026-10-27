# Stage 5: Testing and Sample Queries

## 1. Objective
Prove the system works and that the database enforces every rule.
- **Sample queries** cover each SQL concept in the syllabus, with expected output.
- **Edge-case tests** break each rule on purpose.
- **A test-case document** records expected vs actual results for the report.

## 2. What we did
1. Wrote `sql/queries.sql`: 18 read-only queries covering:
   - INNER and LEFT JOIN
   - GROUP BY, COUNT / MIN / MAX / AVG, HAVING
   - scalar, IN and correlated NOT EXISTS subqueries
   - ORDER BY + LIMIT
   - views, the stored function, SHOW and EXPLAIN
2. Computed the expected output of each query from the seed data and wrote it under the query.
3. Wrote `tests/edge_cases.sql`: 21 tests that break each constraint, trigger and referential action once.
   - Destructive tests (CASCADE, SET NULL, deleting an empty room) run inside `START TRANSACTION ... ROLLBACK`, so no data is lost.
   - **Student number 101:** a temporary stored procedure fills the hostel to exactly 100 students, the 101st insert is blocked by the trigger, then everything is cleaned up.
4. Wrote `tests/test_cases.md`: 83 test cases (21 database, 24 student module, 20 attendance module, 18 queries), with Expected, Actual and Result columns and a summary table.

## 3. Files created or modified
| File | Purpose |
|------|---------|
| `sql/queries.sql` | 18 sample queries with expected output (read-only) |
| `tests/edge_cases.sql` | 21 database-level rule tests, including the 101st student |
| `tests/test_cases.md` | All 83 test cases: expected vs actual, pass/fail summary |
| `docs/README_STAGE5.md` | This file |

## 4. Technologies and tools used
| Technology | Version | Why used |
|-----------|---------|----------|
| MySQL Server | 8.0.44 | Runs the queries and tests |
| MySQL Command Line Client | 8.0 | `SOURCE` keeps running after an error, so one run shows every error |
| MySQL Workbench | 8.0 | Running single queries (Ctrl+Enter) and viewing result grids |
| Stored procedure + WHILE loop | MySQL 8 | Generates 88 test students for the 100-limit test |
| Python application | Stages 3-4 | Module tests (Parts B and C) |

## 5. Key concepts covered
| Concept | Query / test |
|---------|--------------|
| INNER JOIN vs LEFT JOIN | Q1, Q2 (LEFT keeps the empty room B202) |
| GROUP BY + aggregates | Q3, Q4, Q5, Q10, Q11 |
| WHERE vs HAVING | Q6, Q14 (HAVING filters groups after aggregation) |
| Scalar subquery | Q7 (compare with the average) |
| Subquery with IN | Q8 |
| Correlated subquery, NOT EXISTS | Q9 |
| Conditional aggregation | Q10 `SUM(status = 'Present')` |
| ORDER BY + LIMIT | Q12 |
| Views (including a view on a view) | Q11, Q13, Q16 |
| Stored function | Q17 |
| Derived attribute | Q15 (age from date of birth) |
| Query plan, index use | Q18 `EXPLAIN` (`LIKE 'Ra%'` vs `'%vi%'`) |
| Entity integrity (PK) | E3 |
| Domain integrity (CHECK, DATE, UNIQUE) | E4–E10, E14, E16 |
| Referential integrity (FK) | E11, E15 |
| Business rules via triggers | E1, E2, E21 |
| ON DELETE CASCADE / RESTRICT / SET NULL | E18, E17 and E20, E19 |
| Transactions: START TRANSACTION / ROLLBACK | E18, E19, E20 |
| Stored procedure with a loop | Part E (`sp_fill_to_100`) |
| Black-box testing (expected vs actual) | `test_cases.md` |

## 6. How to run / test this stage
**Step 1: fresh database.** In MySQL Command Line Client:
```sql
SOURCE D:/hostel-management/sql/schema.sql;
SOURCE D:/hostel-management/sql/seed.sql;
```
**Step 2: sample queries.** Open `sql/queries.sql` in Workbench and run each query
with Ctrl+Enter (cursor on the query). Compare with the `-- Expected` lines.

**Step 3: edge cases.** In the Command Line Client:
```sql
SOURCE D:/hostel-management/tests/edge_cases.sql;
```
Most statements are meant to fail. Check that each error matches the
`-- Expected` line above it. In Workbench, switch on "continue after failed
statements" (toolbar toggle) before running the whole file.

**Step 4: application tests.** Run `python main.py` and follow Parts B and C of
`tests/test_cases.md`. Note the order instructions in Part C.

**Step 5:** fill in the Actual and Result columns and the summary table.

## 7. Output / results
Edge-case run (excerpt):
```
ERROR 1644 (45000): Room A101 is full (capacity 4).
ERROR 1644 (45000): Room B201 is full (capacity 4).
ERROR 1062 (23000): Duplicate entry '101' for key 'student.PRIMARY'
ERROR 3819 (HY000): Check constraint 'chk_student_phone' is violated.
ERROR 1292 (22007): Incorrect date value: '2005-02-30' for column 'date_of_birth' at row 1
...
ERROR 1062 (23000): Duplicate entry '101-2026-10-01' for key 'attendance.uq_attendance_day'
...
+-------------+      +------------+      +---------------+
| rows_before |      | rows_after |      | rows_restored |
|          10 |      |          0 |      |            10 |
+-------------+      +------------+      +---------------+
...
+----------------+
| total_students |
|            100 |
+----------------+
ERROR 1644 (45000): Hostel is full: maximum 100 students allowed.
+-----------+
| still_100 |
|       100 |
+-----------+
+--------------+
| back_to_seed |
|           12 |
+--------------+
```
Q5, overall statistics: `12 | 50.00 | 100.00 | 83.33`

Q13, defaulters with guardian contact: 108 (50.00), 104 (60.00), 112 (70.00)

For the report, take screenshots of E1, E13, E18 and E21.

## 8. Issues faced and fixes
| Issue | Fix |
|-------|-----|
| Testing the 100-student limit needs 88 extra rows | Temporary stored procedure with a WHILE loop, dropped after the test |
| 88 test students would also hit the room-capacity trigger | The procedure creates 22 test rooms and puts exactly 4 students in each |
| Cascade and SET NULL tests would destroy the seed data | Wrapped in `START TRANSACTION ... ROLLBACK` |
| Workbench stops a script at the first error | Use the Command Line Client `SOURCE`, or turn on "continue after failed statements" |
| Workbench safe-update mode blocks DELETE without a key in WHERE | Every DELETE filters on the primary key (`=` or `BETWEEN`) |
| Attendance tests change percentages for later tests | Order notes in `test_cases.md`, or reload `seed.sql` between parts |
| `EXPLAIN` on 12 rows may show a full scan even when an index exists | Explained in Q18: the optimizer picks a scan for tiny tables. `possible_keys` still shows the index |

## 9. Next stage
**Stage 6: Final documentation.**
- `docs/report_outline.md` (Introduction to Future Scope)
- `docs/viva_questions.md` (10 viva questions with short answers)
- the combined final `README.md` at the project root
