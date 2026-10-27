# Project Report Outline
## Government Hostel Management System: Student Records and Attendance

Suggested length: 25 to 35 pages. Each section lists what to write and which
project file to take the content from.

---

### Front matter
- Title page (project title, course: Database Management Systems, team members, guide, department, college, academic year)
- Certificate
- Acknowledgement
- Abstract (150–200 words). Problem, approach (MySQL 8 + Python CLI, 3NF schema,
  triggers and views), key results (100-student limit, duplicate-free attendance,
  automatic defaulter list), and 83 test cases.
- Table of contents, list of figures, list of tables

---

### Chapter 1. Introduction
1.1 Background: hostel registers are kept on paper today. Describe how attendance and admissions are recorded now.
1.2 Why a DBMS: compare file/paper storage with a DBMS. Cover redundancy, inconsistency, concurrent access, integrity, security and querying.
1.3 Organisation of the report

### Chapter 2. Problem Statement
- Paper registers cause duplicate entries, lost pages, slow percentage calculation, no limit enforcement and no quick search.
- One-paragraph formal statement: *"To design and implement a normalized relational
  database with an application interface that maintains student records and daily
  attendance for a government hostel of at most 100 students, enforcing all
  business rules at the database level."*

### Chapter 3. Objectives
1. Design an ER model and a relational schema in 3NF.
2. Enforce integrity using PK, FK, UNIQUE, CHECK, NOT NULL and triggers.
3. Provide CRUD and search for student records.
4. Record daily attendance without duplicates and compute percentages automatically.
5. Generate the defaulter list (below 75%).
6. Test every rule and document the results.

### Chapter 4. Scope
- **In scope:**
  - single hostel, at most 100 students, rooms of up to 4 beds
  - one admin role (warden)
  - student records and daily attendance
- **Out of scope:** fees, mess, visitors, multiple hostels, web or mobile access (see Chapter 11)
- **Assumptions:**
  - attendance is taken once a day
  - Leave counts as a working day but not as present

### Chapter 5. Requirements
5.1 Functional requirements: table FR1–FR13 (from `docs/README_STAGE0.md`)
5.2 Non-functional requirements: integrity, simplicity, reliability, scale
5.3 Validation rules
5.4 Hardware requirements: any PC with 4 GB RAM, about 1 GB disk
5.5 Software requirements: Windows 10/11, MySQL 8.0.44, Python 3.10+, mysql-connector-python, tabulate, Git

### Chapter 6. System Design (core chapter for DBMS)
6.1 System architecture: Python CLI (client) → mysql-connector → MySQL server.
    Draw the 3-layer figure: UI menus / modules (student.py, attendance.py) / db.py → MySQL.
6.2 ER diagram: figure from `docs/er_diagram.md`. Cover entities, attributes (key and derived) and cardinalities.
6.3 Relational schema: the 4 tables with data types and constraints (Part 2 of `er_diagram.md`).
6.4 Normalization (Part 3 of `er_diagram.md`):
- the UNF paper register and its insert, update and delete anomalies
- 1NF → 2NF → 3NF steps, the functional dependencies of each table, and the BCNF check
6.5 Integrity constraints: table of every named constraint and what it blocks
6.6 Referential actions: why CASCADE, RESTRICT and SET NULL were each chosen
6.7 Views, triggers and function: purpose of each and why a trigger is needed (a CHECK cannot count rows)
6.8 Indexes: which columns and why. The `LIKE 'Ra%'` vs `'%vi%'` example
6.9 Menu / flow diagram: login → main menu → student menu and attendance menu

### Chapter 7. Implementation
7.1 Folder structure (from `README.md`)
7.2 Database implementation: key extracts from `schema.sql` (one table, one trigger, one view, the function)
7.3 Application modules: `db.py` (helpers, transactions), `student.py`, `attendance.py`, `main.py`
7.4 Security:
- parameterized queries (SQL injection prevention)
- SHA-256 password hashing
- whitelist for updatable columns
- the password kept out of Git
7.5 Screenshots:
- login
- main menu
- add student
- display all
- search
- update
- delete confirmation
- mark attendance
- view by date
- monthly report
- defaulter list

### Chapter 8. Testing
8.1 Testing strategy: database-level tests, module tests, query verification
8.2 Test cases: the four tables from `tests/test_cases.md` with Actual and Result filled in
8.3 Edge cases: screenshots of E1 (room full), E13 (duplicate attendance), E18 (cascade + rollback), E21 (student number 101)
8.4 Sample queries: Q1–Q17 with output (from `sql/queries.sql`)
8.5 Test summary: passed / total

### Chapter 9. Results and Discussion
- All rules hold even when the application is bypassed (direct SQL), because they live in the database.
- Percentages are always current, because they are computed in a view and never stored.
- Compare with the paper register: time to find a defaulter, chance of duplicates.

### Chapter 10. Conclusion
- Objectives met: a 3NF design, enforced integrity, working CRUD and attendance, automatic reports.
- What was learned: normalization, constraints vs triggers, transactions, views.

### Chapter 11. Limitations and Future Scope
**Limitations**
- Single admin account and a command-line interface only.
- Local database. It is not reachable from other computers or phones.
- Attendance once per day only (no morning/evening roll call).
- Lowering a room's capacity below its current occupancy is not blocked (no trigger on `room`).
- No backup or restore option inside the application.

**Future scope**
1. **Fee management:** FEE and PAYMENT tables (student_id FK, amount, due_date, paid_on), a dues view, and receipts.
2. **Mess management:** MESS_MENU, meal attendance and monthly mess bills linked to the student.
3. **SMS alerts to guardians:** use `guardian_phone` and `v_defaulters` to send weekly alerts through an SMS gateway API.
4. Multiple roles (warden, clerk, read-only principal) with an ADMIN.role column.
5. A web or mobile interface (Flask / Android) on the same database.
6. Biometric or QR-based attendance marking.
7. Room-change history (an audit table filled by a trigger).

### References
- Silberschatz, Korth, Sudarshan: *Database System Concepts*, 7th ed., McGraw-Hill.
- Elmasri, Navathe: *Fundamentals of Database Systems*, 7th ed., Pearson.
- MySQL 8.0 Reference Manual (dev.mysql.com/doc/refman/8.0/en/)
- MySQL Connector/Python Developer Guide
- Python 3 documentation (docs.python.org)

### Appendices
- A: Complete `schema.sql`
- B: `seed.sql` (or a summary)
- C: Source code listings
- D: User manual (setup and run steps from `README.md`)
