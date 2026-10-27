# Viva Questions with Short Answers
## Government Hostel Management System

---

**1. Why did you split room details into a separate ROOM table? Which normal form does this achieve?**

In a single table there is a transitive dependency
`student_id → room_no → floor, capacity`. The floor and capacity describe the
room, not the student. Keeping them in STUDENT repeats them for every occupant,
which causes update, insert and delete anomalies. Moving them to ROOM, and keeping
only `room_no` as a foreign key in STUDENT, removes the transitive dependency.
That puts the table in **3NF**. All four tables are also in BCNF, because every
determinant is a candidate key.

---

**2. What is the difference between ON DELETE CASCADE, RESTRICT and SET NULL? Where did you use each?**

| Action | Meaning | Used on | Reason |
|--------|---------|---------|--------|
| CASCADE | Deleting the parent deletes its child rows | attendance → student | Attendance has no meaning without the student |
| RESTRICT | Blocks deleting a parent that has children | student → room | Deleting a room must not silently delete its students |
| SET NULL | Child row stays, the FK becomes NULL | attendance → admin | Keep attendance history even if an admin account is removed |

---

**3. How do you prevent duplicate attendance for the same student on the same day?**

With a composite UNIQUE constraint, `UNIQUE(student_id, att_date)`. A second
insert for the same pair fails with error 1062. The application also lists only
students not yet marked for that date, using a `NOT EXISTS` subquery. Mistakes are
fixed with UPDATE, not a second INSERT.

---

**4. Why did you use a trigger for the 100-student limit instead of a CHECK constraint?**

A CHECK constraint is evaluated on one row at a time and cannot look at other
rows, so it cannot count how many students exist. A **BEFORE INSERT trigger** runs
`SELECT COUNT(*) FROM student`. If the count is already 100, it raises
`SIGNAL SQLSTATE '45000'`, which cancels the insert. Room capacity uses triggers
for the same reason.

---

**5. Why is attendance percentage not stored as a column?**

It is a **derived attribute**. A stored percentage would go out of date after
every new attendance entry, which creates an update anomaly and redundancy. It is
calculated in the view `v_attendance_summary` as
`present days / total days marked × 100`, so it is always current. Age is handled
the same way: it is computed from `date_of_birth` with `TIMESTAMPDIFF`.

---

**6. What is a view? How is it different from a table?**

A view is a **stored SELECT query** that behaves like a virtual table. It holds no
data of its own. Every time it is queried, it reads the current data from the base
tables. We use three views:
- `v_attendance_summary`
- `v_defaulters`, which is a view built on top of another view
- `v_room_occupancy`

Views simplify complex queries, hide joins from the application, and can restrict
which columns a user sees.

---

**7. How does your application prevent SQL injection?**

Every query uses **parameterized placeholders** (`%s`), for example
`SELECT * FROM student WHERE student_id = %s`. The driver sends the value
separately from the SQL text, so input like `1 OR 1=1` is treated as plain data
and never as SQL code.

Column names cannot be placeholders. For the update option, the column name is
taken only from a fixed whitelist (`UPDATABLE_FIELDS`).

---

**8. What is a transaction? Where did you use COMMIT and ROLLBACK?**

A transaction is a group of operations that succeed or fail together. It follows
the ACID properties: Atomicity, Consistency, Isolation and Durability.

When a whole day's attendance is saved, all inserts run in one transaction
(`execute_many`). If any row fails, for example a duplicate, **ROLLBACK** undoes
them all, so a half-marked day is never saved. Otherwise, **COMMIT** makes them
permanent.

The edge-case tests also use `START TRANSACTION ... ROLLBACK` to demonstrate
CASCADE without losing data.

---

**9. What is the difference between WHERE and HAVING? Give an example from your project.**

- `WHERE` filters **rows before** grouping. It cannot use aggregate functions.
- `HAVING` filters **groups after** GROUP BY. It can use aggregates.

Example (full rooms):
```sql
SELECT r.room_no, COUNT(s.student_id)
FROM room r JOIN student s ON s.room_no = r.room_no
GROUP BY r.room_no, r.capacity
HAVING COUNT(s.student_id) = r.capacity;
```
The condition on `COUNT(...)` can only go in HAVING.

---

**10. Why did you create an index on full_name? Does it help every search?**

An index (a B-tree in InnoDB) lets MySQL find matching names without scanning the
whole table.

It helps only when the pattern starts with fixed text:
- `LIKE 'Ra%'` can use the index.
- `LIKE '%vi%'` cannot, because a leading wildcard means any position could match.

`EXPLAIN` shows this. Primary key, UNIQUE and foreign key columns are indexed
automatically. We added indexes only on `full_name` and `att_date`, the columns we
search and filter on.

---

### Possible follow-up questions (quick answers)
| Question | Short answer |
|----------|--------------|
| Primary key vs unique key? | Only one PK per table, and it cannot be NULL. A table can have many UNIQUE keys. In MySQL a UNIQUE column can hold NULL. |
| Natural vs surrogate key? | `room_no` is natural (it has meaning). `attendance_id` is surrogate (auto-number with no meaning). |
| What is a candidate key in ATTENDANCE? | `attendance_id`, and also `(student_id, att_date)`. |
| INNER JOIN vs LEFT JOIN? | INNER keeps only matching rows. LEFT keeps every left-table row, with NULLs where there is no match (the empty room B202). |
| Correlated subquery? | The inner query uses a column of the outer row, so it runs once per outer row (the `NOT EXISTS` check). |
| Why hash passwords? | If the database is leaked, the real password is not revealed. We store `SHA2('admin123', 256)`. |
| What does `SIGNAL SQLSTATE '45000'` do? | Raises a user-defined error from a trigger or procedure and cancels the statement. |
| Function vs procedure? | A function returns one value and can be used inside SELECT (`fn_attendance_pct`). A procedure is invoked with CALL and can change data (`sp_fill_to_100`). |
| DDL vs DML? | DDL defines structure (CREATE, ALTER, DROP). DML works with data (INSERT, UPDATE, DELETE, SELECT). |
| Why CHAR(10) for phone and not INT? | Phone numbers are not used in arithmetic. They can start with 0, and INT has no fixed length. |
