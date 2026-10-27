-- =====================================================================
-- schema.sql
-- Government Hostel Management System: Student Records and Attendance
-- DBMS: MySQL 8.0.16 or later (CHECK constraints are enforced from 8.0.16)
--
-- What this file creates:
--   4 tables  : admin, room, student, attendance
--   2 indexes : student(full_name), attendance(att_date)
--   3 views   : v_attendance_summary, v_defaulters, v_room_occupancy
--   3 triggers: 100-student limit, room capacity on insert, room capacity on update
--   1 function: fn_attendance_pct(student_id)
--
-- WARNING: this script DROPS and recreates hostel_db. All data is lost.
-- Run seed.sql right after it to load sample data again.
-- =====================================================================

-- Start fresh: remove the old database (if any) and create a new one.
DROP DATABASE IF EXISTS hostel_db;
CREATE DATABASE hostel_db CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE hostel_db;


-- ---------------------------------------------------------------------
-- TABLE 1: admin
-- The warden who logs in. The password is stored as a SHA-256 hash,
-- never as plain text.
-- ---------------------------------------------------------------------
CREATE TABLE admin (
    admin_id       INT          AUTO_INCREMENT,
    username       VARCHAR(30)  NOT NULL,
    password_hash  CHAR(64)     NOT NULL,          -- SHA-256 = 64 hex characters
    full_name      VARCHAR(60)  NOT NULL,

    CONSTRAINT pk_admin          PRIMARY KEY (admin_id),
    CONSTRAINT uq_admin_username UNIQUE (username)
);


-- ---------------------------------------------------------------------
-- TABLE 2: room
-- Stored separately from student to remove the transitive dependency
-- student_id -> room_no -> capacity (3NF).
-- ---------------------------------------------------------------------
CREATE TABLE room (
    room_no   VARCHAR(10)  NOT NULL,
    floor     INT          NOT NULL,
    capacity  INT          NOT NULL DEFAULT 4,

    CONSTRAINT pk_room          PRIMARY KEY (room_no),
    CONSTRAINT chk_room_floor   CHECK (floor BETWEEN 0 AND 5),
    CONSTRAINT chk_room_capacity CHECK (capacity BETWEEN 1 AND 4)
);


-- ---------------------------------------------------------------------
-- TABLE 3: student
-- One row per hostel resident.
-- ---------------------------------------------------------------------
CREATE TABLE student (
    student_id      INT           NOT NULL,        -- hostel ID typed by warden
    full_name       VARCHAR(60)   NOT NULL,
    gender          CHAR(1)       NOT NULL,
    date_of_birth   DATE          NOT NULL,        -- DATE type rejects 2026-02-30
    phone           CHAR(10)      NOT NULL,
    guardian_name   VARCHAR(60)   NOT NULL,
    guardian_phone  CHAR(10)      NOT NULL,
    address         VARCHAR(200)  NOT NULL,
    course          VARCHAR(40)   NOT NULL,
    year_of_study   INT           NOT NULL,
    room_no         VARCHAR(10)   NOT NULL,
    admission_date  DATE          NOT NULL,

    CONSTRAINT pk_student            PRIMARY KEY (student_id),
    CONSTRAINT uq_student_phone      UNIQUE (phone),
    CONSTRAINT chk_student_name      CHECK (TRIM(full_name) <> ''),
    CONSTRAINT chk_student_gender    CHECK (gender IN ('M', 'F', 'O')),
    CONSTRAINT chk_student_phone     CHECK (phone REGEXP '^[0-9]{10}$'),
    CONSTRAINT chk_guardian_phone    CHECK (guardian_phone REGEXP '^[0-9]{10}$'),
    CONSTRAINT chk_student_year      CHECK (year_of_study BETWEEN 1 AND 5),
    CONSTRAINT chk_admission_after_dob CHECK (admission_date > date_of_birth),

    -- RESTRICT: a room cannot be deleted while students live in it.
    -- CASCADE on update: if a room is renumbered, students follow automatically.
    CONSTRAINT fk_student_room FOREIGN KEY (room_no)
        REFERENCES room (room_no)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);


-- ---------------------------------------------------------------------
-- TABLE 4: attendance
-- One row per student per day. UNIQUE(student_id, att_date) blocks
-- marking the same student twice on the same date.
-- ---------------------------------------------------------------------
CREATE TABLE attendance (
    attendance_id  INT          AUTO_INCREMENT,
    student_id     INT          NOT NULL,
    att_date       DATE         NOT NULL,          -- not "date": DATE is a keyword
    status         VARCHAR(7)   NOT NULL,
    marked_by      INT          NULL,              -- which admin marked it

    CONSTRAINT pk_attendance        PRIMARY KEY (attendance_id),
    CONSTRAINT uq_attendance_day    UNIQUE (student_id, att_date),
    CONSTRAINT chk_attendance_status CHECK (status IN ('Present', 'Absent', 'Leave')),

    -- CASCADE: deleting a student deletes their attendance too.
    CONSTRAINT fk_attendance_student FOREIGN KEY (student_id)
        REFERENCES student (student_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    -- SET NULL: removing an admin keeps the attendance records.
    CONSTRAINT fk_attendance_admin FOREIGN KEY (marked_by)
        REFERENCES admin (admin_id)
        ON DELETE SET NULL
);


-- ---------------------------------------------------------------------
-- INDEXES on searched columns
-- (PRIMARY KEY, UNIQUE and FOREIGN KEY columns are indexed automatically.)
-- ---------------------------------------------------------------------
-- Speeds up name search. Note: LIKE 'Ra%' can use this index,
-- but LIKE '%vi%' (wildcard at the start) cannot.
CREATE INDEX idx_student_name ON student (full_name);

-- Speeds up "view attendance by date" and "by month".
CREATE INDEX idx_attendance_date ON attendance (att_date);


-- ---------------------------------------------------------------------
-- VIEW 1: v_attendance_summary
-- Attendance percentage per student = Present days / days marked x 100.
-- LEFT JOIN keeps students who have no attendance yet (percentage = NULL).
-- SUM(status = 'Present') counts rows where the condition is true (1).
-- NULLIF(..., 0) avoids division by zero.
-- ---------------------------------------------------------------------
CREATE VIEW v_attendance_summary AS
SELECT
    s.student_id,
    s.full_name,
    s.room_no,
    COUNT(a.attendance_id)                     AS total_days,
    COALESCE(SUM(a.status = 'Present'), 0)     AS present_days,
    COALESCE(SUM(a.status = 'Absent'),  0)     AS absent_days,
    COALESCE(SUM(a.status = 'Leave'),   0)     AS leave_days,
    ROUND(SUM(a.status = 'Present') * 100
          / NULLIF(COUNT(a.attendance_id), 0), 2) AS attendance_pct
FROM student s
LEFT JOIN attendance a ON a.student_id = s.student_id
GROUP BY s.student_id, s.full_name, s.room_no;


-- VIEW 2: v_defaulters (students below 75%), built on top of view 1.
CREATE VIEW v_defaulters AS
SELECT student_id, full_name, room_no, total_days, present_days, attendance_pct
FROM v_attendance_summary
WHERE attendance_pct < 75;


-- VIEW 3: v_room_occupancy (beds used and free in every room).
-- Used in Stage 3 to show available rooms while adding a student.
CREATE VIEW v_room_occupancy AS
SELECT
    r.room_no,
    r.floor,
    r.capacity,
    COUNT(s.student_id)              AS occupied,
    r.capacity - COUNT(s.student_id) AS free_beds
FROM room r
LEFT JOIN student s ON s.room_no = r.room_no
GROUP BY r.room_no, r.floor, r.capacity;


-- ---------------------------------------------------------------------
-- TRIGGERS and FUNCTION
-- DELIMITER changes the statement end marker from ; to $$ so that the
-- semicolons inside BEGIN ... END do not end the CREATE statement early.
-- SIGNAL SQLSTATE '45000' raises a custom error and cancels the INSERT/UPDATE.
-- ---------------------------------------------------------------------
DELIMITER $$

-- TRIGGER 1: block the 101st student.
-- A CHECK constraint cannot do this, because a CHECK sees only one row
-- and cannot count the other rows in the table.
CREATE TRIGGER trg_student_limit
BEFORE INSERT ON student
FOR EACH ROW
BEGIN
    DECLARE total_students INT;
    SELECT COUNT(*) INTO total_students FROM student;
    IF total_students >= 100 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Hostel is full: maximum 100 students allowed.';
    END IF;
END$$


-- TRIGGER 2: block adding a student to a full room.
CREATE TRIGGER trg_room_capacity_insert
BEFORE INSERT ON student
FOR EACH ROW
BEGIN
    DECLARE max_beds INT;
    DECLARE occupied INT;
    DECLARE msg VARCHAR(128);

    -- Subquery form returns NULL (no warning) if the room does not exist;
    -- the foreign key then rejects the row with its own error.
    SET max_beds = (SELECT capacity FROM room WHERE room_no = NEW.room_no);
    SET occupied = (SELECT COUNT(*) FROM student WHERE room_no = NEW.room_no);

    IF max_beds IS NOT NULL AND occupied >= max_beds THEN
        SET msg = CONCAT('Room ', NEW.room_no, ' is full (capacity ', max_beds, ').');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
END$$


-- TRIGGER 3: same capacity rule when a student is MOVED to another room.
CREATE TRIGGER trg_room_capacity_update
BEFORE UPDATE ON student
FOR EACH ROW
BEGIN
    DECLARE max_beds INT;
    DECLARE occupied INT;
    DECLARE msg VARCHAR(128);

    IF NEW.room_no <> OLD.room_no THEN          -- only when the room changes
        SET max_beds = (SELECT capacity FROM room WHERE room_no = NEW.room_no);
        SET occupied = (SELECT COUNT(*) FROM student WHERE room_no = NEW.room_no);

        IF max_beds IS NOT NULL AND occupied >= max_beds THEN
            SET msg = CONCAT('Room ', NEW.room_no, ' is full (capacity ', max_beds, ').');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
        END IF;
    END IF;
END$$


-- FUNCTION: attendance percentage of one student.
-- READS SQL DATA tells MySQL the function only reads tables (needed
-- because binary logging is on by default in MySQL 8).
-- Returns NULL if the student has no attendance marked yet.
CREATE FUNCTION fn_attendance_pct(p_student_id INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE total_days INT;
    DECLARE present_days INT;

    SET total_days   = (SELECT COUNT(*) FROM attendance
                        WHERE student_id = p_student_id);
    SET present_days = (SELECT COUNT(*) FROM attendance
                        WHERE student_id = p_student_id AND status = 'Present');

    IF total_days = 0 THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(present_days * 100 / total_days, 2);
END$$

DELIMITER ;

-- Quick confirmation when the script finishes.
SHOW TABLES;
