-- =====================================================================
-- edge_cases.sql
-- Deliberately breaks every rule once, to prove the DATABASE blocks it.
-- Most statements here are SUPPOSED to fail. The expected error is written
-- above each one.
--
-- BEFORE RUNNING: reload a fresh database (schema.sql, then seed.sql).
--
-- HOW TO RUN (recommended): MySQL 8.0 Command Line Client
--     SOURCE D:/hostel-management/tests/edge_cases.sql;
--   The client keeps going after each error and prints it, so you see
--   every result in order (good for report screenshots).
--
-- In Workbench: first click the toolbar toggle "Toggle whether execution
--   of SQL script should continue after failed statements", then run all
--   with the plain lightning bolt.
--
-- AFTER RUNNING: the data is back to the seed state (tests that change
-- data are cleaned up or rolled back), but reloading seed.sql is safest.
-- =====================================================================
USE hostel_db;


-- =====================================================================
-- PART A: STUDENT TABLE RULES
-- =====================================================================

-- E1. Room full (A101 has 4/4)            -> trigger trg_room_capacity_insert
-- Expected: ERROR 1644 (45000): Room A101 is full (capacity 4).
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'A101','2026-07-01');

-- E2. Move a student into a full room     -> trigger trg_room_capacity_update
-- Expected: ERROR 1644 (45000): Room B201 is full (capacity 4).
UPDATE student SET room_no = 'B201' WHERE student_id = 105;

-- E3. Duplicate student_id                -> PRIMARY KEY
-- Expected: ERROR 1062 (23000): Duplicate entry '101' for key 'student.PRIMARY'
INSERT INTO student VALUES (101,'Copy Student','M','2005-01-01','9000000199',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2026-07-01');

-- E4. Duplicate phone (Ravi's number)     -> UNIQUE uq_student_phone
-- Expected: ERROR 1062 (23000): Duplicate entry '9876500101' for key 'student.uq_student_phone'
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','9876500101',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2026-07-01');

-- E5. Phone not 10 digits                 -> CHECK chk_student_phone
-- Expected: ERROR 3819 (HY000): Check constraint 'chk_student_phone' is violated.
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','12345',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2026-07-01');

-- E6. Blank name (spaces only)            -> CHECK chk_student_name
-- Expected: ERROR 3819 (HY000): Check constraint 'chk_student_name' is violated.
INSERT INTO student VALUES (113,'   ','M','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2026-07-01');

-- E7. Impossible date 30 Feb              -> DATE type + strict SQL mode
-- Expected: ERROR 1292 (22007): Incorrect date value: '2005-02-30' for column 'date_of_birth' at row 1
INSERT INTO student VALUES (113,'Test Boy','M','2005-02-30','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2026-07-01');

-- E8. Invalid gender                      -> CHECK chk_student_gender
-- Expected: ERROR 3819 (HY000): Check constraint 'chk_student_gender' is violated.
INSERT INTO student VALUES (113,'Test Boy','X','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2026-07-01');

-- E9. Year of study out of range          -> CHECK chk_student_year
-- Expected: ERROR 3819 (HY000): Check constraint 'chk_student_year' is violated.
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',7,'B202','2026-07-01');

-- E10. Admission before date of birth     -> CHECK chk_admission_after_dob
-- Expected: ERROR 3819 (HY000): Check constraint 'chk_admission_after_dob' is violated.
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2004-07-01');

-- E11. Room that does not exist           -> FOREIGN KEY fk_student_room
-- Expected: ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails ...
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'Z999','2026-07-01');

-- E12. Valid student into a room with space: must SUCCEED, then remove it.
-- Expected: Query OK, 1 row affected   (twice)
INSERT INTO student VALUES (113,'Test Boy','M','2005-01-01','9000000113',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2026-07-01');
DELETE FROM student WHERE student_id = 113;


-- =====================================================================
-- PART B: ATTENDANCE TABLE RULES
-- =====================================================================

-- E13. Duplicate attendance, same student same date -> UNIQUE uq_attendance_day
-- Expected: ERROR 1062 (23000): Duplicate entry '101-2026-10-01' for key 'attendance.uq_attendance_day'
INSERT INTO attendance (student_id, att_date, status, marked_by)
VALUES (101, '2026-10-01', 'Absent', 1);

-- E14. Invalid status                     -> CHECK chk_attendance_status
-- Expected: ERROR 3819 (HY000): Check constraint 'chk_attendance_status' is violated.
INSERT INTO attendance (student_id, att_date, status, marked_by)
VALUES (101, '2026-10-11', 'Late', 1);

-- E15. Attendance for a student who does not exist -> FOREIGN KEY fk_attendance_student
-- Expected: ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails ...
INSERT INTO attendance (student_id, att_date, status, marked_by)
VALUES (999, '2026-10-11', 'Present', 1);


-- =====================================================================
-- PART C: ROOM TABLE RULES
-- =====================================================================

-- E16. Capacity above 4                   -> CHECK chk_room_capacity
-- Expected: ERROR 3819 (HY000): Check constraint 'chk_room_capacity' is violated.
INSERT INTO room (room_no, floor, capacity) VALUES ('C301', 3, 6);

-- E17. Delete a room that has students    -> FOREIGN KEY ... ON DELETE RESTRICT
-- Expected: ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails ...
DELETE FROM room WHERE room_no = 'A101';


-- =====================================================================
-- PART D: REFERENTIAL ACTIONS (inside a transaction, then ROLLBACK,
-- so the seed data is not lost)
-- =====================================================================

-- E18. ON DELETE CASCADE: deleting a student deletes their attendance.
START TRANSACTION;
SELECT COUNT(*) AS rows_before FROM attendance WHERE student_id = 112;  -- Expected: 10
DELETE FROM student WHERE student_id = 112;                             -- Expected: 1 row affected
SELECT COUNT(*) AS rows_after  FROM attendance WHERE student_id = 112;  -- Expected: 0 (cascaded)
ROLLBACK;
SELECT COUNT(*) AS rows_restored FROM attendance WHERE student_id = 112; -- Expected: 10 (rollback)

-- E19. ON DELETE SET NULL: deleting an admin keeps the attendance row.
START TRANSACTION;
INSERT INTO admin (username, password_hash, full_name)
VALUES ('temp', SHA2('temp', 256), 'Temporary Admin');
INSERT INTO attendance (student_id, att_date, status, marked_by)
VALUES (101, '2026-10-11', 'Present', LAST_INSERT_ID());
DELETE FROM admin WHERE username = 'temp';
SELECT student_id, att_date, status, marked_by
FROM attendance WHERE student_id = 101 AND att_date = '2026-10-11';
-- Expected: 101 | 2026-10-11 | Present | NULL
ROLLBACK;

-- E20. An EMPTY room can be deleted (RESTRICT only blocks rooms in use).
START TRANSACTION;
DELETE FROM room WHERE room_no = 'B202';     -- Expected: 1 row affected
ROLLBACK;


-- =====================================================================
-- PART E: THE 100-STUDENT LIMIT (student number 101)
-- A temporary procedure adds 22 test rooms (22 x 4 = 88 beds) and
-- 88 test students (IDs 113 to 200), so the hostel holds exactly 100.
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_fill_to_100;

DELIMITER $$
CREATE PROCEDURE sp_fill_to_100()
BEGIN
    DECLARE i INT DEFAULT 1;

    -- 22 test rooms: T01 ... T22 (ground floor, 4 beds each)
    WHILE i <= 22 DO
        INSERT INTO room (room_no, floor, capacity)
        VALUES (CONCAT('T', LPAD(i, 2, '0')), 0, 4);
        SET i = i + 1;
    END WHILE;

    -- 88 test students: IDs 113-200, 4 per room, unique 10-digit phones
    SET i = 113;
    WHILE i <= 200 DO
        INSERT INTO student VALUES (
            i, CONCAT('Test Student ', i), 'M', '2005-01-01',
            CONCAT('90000', LPAD(i, 5, '0')),
            'Test Guardian', '9000000000', 'Test Address', 'B.Tech CSE', 1,
            CONCAT('T', LPAD(CEIL((i - 112) / 4), 2, '0')),
            '2026-07-01');
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

CALL sp_fill_to_100();
SELECT COUNT(*) AS total_students FROM student;          -- Expected: 100

-- E21. Student number 101                  -> trigger trg_student_limit
-- Expected: ERROR 1644 (45000): Hostel is full: maximum 100 students allowed.
INSERT INTO student VALUES (201,'Student 101','M','2005-01-01','9000000201',
  'Test Guardian','9000000000','Sangli','B.Tech CSE',1,'B202','2026-07-01');

SELECT COUNT(*) AS still_100 FROM student;               -- Expected: 100

-- Clean up Part E: remove test students, test rooms and the procedure.
DELETE FROM student WHERE student_id BETWEEN 113 AND 200;
DELETE FROM room WHERE room_no BETWEEN 'T01' AND 'T22';   -- range on the PK (safe-update friendly)
DROP PROCEDURE sp_fill_to_100;
SELECT COUNT(*) AS back_to_seed FROM student;            -- Expected: 12
