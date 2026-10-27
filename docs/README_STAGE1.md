# Stage 1: Database Design (ER Diagram, Relational Schema, Normalization)

## 1. Objective
Design the database on paper before writing any SQL: identify the entities and
relationships, convert them into tables with keys and constraints, and prove
that the tables are in 3NF.

## 2. What we did
1. Identified 4 entities: ADMIN, ROOM, STUDENT, ATTENDANCE.
2. Listed key, simple and derived attributes. Age and percentage are derived and not stored.
3. Defined 3 one-to-many relationships: Room–Student, Student–Attendance, Admin–Attendance.
4. Drew the ER diagram in Mermaid (crow's-foot notation), plus a text version for the report.
5. Converted the ER diagram into a relational schema with data types and constraints.
6. Chose a referential action for each foreign key: CASCADE, RESTRICT or SET NULL.
7. Normalized the paper register from UNF through 1NF, 2NF and 3NF, and checked BCNF.
8. Listed the rules that need a trigger (100-student limit, room capacity) and the planned indexes.

## 3. Files created or modified
| File | Purpose |
|------|---------|
| `docs/er_diagram.md` | ER diagram, relational schema, design notes, normalization proof |
| `docs/README_STAGE1.md` | This file |

## 4. Technologies and tools used
| Technology | Version | Why used |
|-----------|---------|----------|
| Mermaid | v10+ (mermaid.live / GitHub) | ER diagram written as text, so it lives in Git |
| Markdown | - | Documentation format |
| MySQL Workbench (optional) | 8.0 | Can reverse-engineer the ER diagram from schema.sql in Stage 2 |

## 5. Key concepts covered
- Entity, attribute (key / simple / derived), relationship, cardinality (1:N)
- Primary key: natural key (room_no) vs surrogate key (admin_id, attendance_id)
- Candidate key (username, phone, (student_id, att_date))
- Foreign key and referential actions: ON DELETE CASCADE / RESTRICT / SET NULL, ON UPDATE CASCADE
- Domain constraints: NOT NULL, UNIQUE, CHECK, DEFAULT, DATE type
- Functional dependency, partial dependency, transitive dependency
- Insert, update and delete anomalies
- 1NF, 2NF, 3NF, BCNF
- Why some rules need triggers: CHECK sees one row only

## 6. How to run / test this stage
This is a design stage, so there is no code to run. To verify:
```
1. Open docs/er_diagram.md.
2. Copy the ```mermaid block and paste it into https://mermaid.live.
3. Confirm the diagram shows 4 entities and 3 relationships.
4. Push to GitHub (optional): the diagram renders on the file's page.
```
Self-check questions:
- Which FK uses RESTRICT, and why? (Student → Room, so a room delete cannot wipe out its students)
- Where was the transitive dependency? (student_id → room_no → capacity)

## 7. Output / results
- ER diagram with ROOM 1:N STUDENT 1:N ATTENDANCE N:1 ADMIN.
- Final schema:
  ```
  ADMIN      (admin_id PK, username UK, password_hash, full_name)
  ROOM       (room_no PK, floor, capacity)
  STUDENT    (student_id PK, full_name, gender, date_of_birth, phone UK,
              guardian_name, guardian_phone, address, course,
              year_of_study, room_no FK, admission_date)
  ATTENDANCE (attendance_id PK, student_id FK, att_date, status, marked_by FK,
              UNIQUE(student_id, att_date))
  ```
- All 4 tables proven to be in 3NF and BCNF.

## 8. Issues faced and fixes
| Issue | Fix |
|-------|-----|
| ON DELETE CASCADE on Student → Room would delete students when a room is deleted | Used RESTRICT there. CASCADE only on Attendance → Student |
| Column name `date` is a MySQL keyword | Renamed to `att_date` |
| 100-student limit and room capacity cannot be written as a CHECK | Planned as BEFORE INSERT / BEFORE UPDATE triggers in Stage 2 |
| Room floor and capacity repeated for every student (transitive dependency) | Moved into a separate ROOM table (3NF) |
| Storing attendance percentage would go out of date | Will be computed in a VIEW instead |

## 9. Next stage
**Stage 2: Database implementation.** `schema.sql` with all tables, constraints and
indexes, the attendance-percentage VIEW, triggers for the 100-student limit and
room capacity, and `seed.sql` with 10 to 15 sample students.
