-- =====================================================================
-- seed.sql
-- Sample data: 1 admin, 5 rooms, 12 students, 10 days of attendance.
-- Run AFTER schema.sql (schema.sql gives an empty, fresh database).
--
-- Designed for testing:
--   Room A101 and B201 are FULL (4/4): use them to test the capacity trigger.
--   Room B202 is EMPTY: shows a room can exist with no students (no insert anomaly).
--   Students 104, 108, 112 are below 75%: they appear in v_defaulters.
-- =====================================================================
USE hostel_db;

-- ---------------------------------------------------------------------
-- Admin login: username = warden, password = admin123
-- SHA2('admin123', 256) stores the SHA-256 hash, not the plain password.
-- ---------------------------------------------------------------------
INSERT INTO admin (username, password_hash, full_name) VALUES
  ('warden', SHA2('admin123', 256), 'Hostel Warden');

-- ---------------------------------------------------------------------
-- Rooms: block A (boys), block B (girls)
-- ---------------------------------------------------------------------
INSERT INTO room (room_no, floor, capacity) VALUES
  ('A101', 1, 4),
  ('A102', 1, 4),
  ('A103', 1, 2),
  ('B201', 2, 4),
  ('B202', 2, 4);

-- ---------------------------------------------------------------------
-- Students (12)
-- Column order: student_id, full_name, gender, date_of_birth, phone,
-- guardian_name, guardian_phone, address, course, year_of_study,
-- room_no, admission_date
-- ---------------------------------------------------------------------
INSERT INTO student VALUES
  (101, 'Ravi Patil',      'M', '2005-03-14', '9876500101', 'Suresh Patil',    '9822000101', 'At Post Kagal, Dist. Kolhapur',     'B.Tech AIML',  2, 'A101', '2024-07-15'),
  (102, 'Amit Kale',       'M', '2005-08-22', '9876500102', 'Ramesh Kale',     '9822000102', 'Shivaji Peth, Sangli',              'B.Tech CSE',   2, 'A101', '2024-07-15'),
  (103, 'Sagar Jadhav',    'M', '2004-11-02', '9876500103', 'Vilas Jadhav',    '9822000103', 'At Post Tasgaon, Dist. Sangli',     'B.Tech Civil', 3, 'A101', '2023-07-20'),
  (104, 'Pranav Shinde',   'M', '2006-01-30', '9876500104', 'Anil Shinde',     '9822000104', 'Rajarampuri, Kolhapur',             'B.Tech Mech',  1, 'A101', '2025-08-01'),
  (105, 'Omkar Pawar',     'M', '2004-06-18', '9876500105', 'Dattatray Pawar', '9822000105', 'At Post Miraj, Dist. Sangli',       'B.Tech AIML',  3, 'A102', '2023-07-20'),
  (106, 'Rohit Mane',      'M', '2005-12-09', '9876500106', 'Shankar Mane',    '9822000106', 'Kasba Peth, Satara',                'B.Tech ENTC',  2, 'A102', '2024-07-15'),
  (107, 'Vishal Gaikwad',  'M', '2003-09-25', '9876500107', 'Ashok Gaikwad',   '9822000107', 'At Post Islampur, Dist. Sangli',    'B.Tech CSE',   4, 'A102', '2022-08-10'),
  (108, 'Nikhil Chavan',   'M', '2006-04-11', '9876500108', 'Prakash Chavan',  '9822000108', 'At Post Vita, Dist. Sangli',        'B.Tech Electrical', 1, 'A103', '2025-08-01'),
  (109, 'Sneha Kulkarni',  'F', '2005-02-27', '9876500109', 'Madhav Kulkarni', '9822000109', 'Vishrambag, Sangli',                'B.Tech AIML',  2, 'B201', '2024-07-15'),
  (110, 'Pooja Deshmukh',  'F', '2004-07-05', '9876500110', 'Sunil Deshmukh',  '9822000110', 'At Post Karad, Dist. Satara',       'B.Tech CSE',   3, 'B201', '2023-07-20'),
  (111, 'Priya More',      'F', '2006-10-19', '9876500111', 'Balasaheb More',  '9822000111', 'Shahupuri, Kolhapur',               'B.Tech Civil', 1, 'B201', '2025-08-01'),
  (112, 'Anjali Salunkhe', 'F', '2003-12-01', '9876500112', 'Rajendra Salunkhe','9822000112','At Post Wai, Dist. Satara',         'B.Tech ENTC',  4, 'B201', '2022-08-10');

-- ---------------------------------------------------------------------
-- Attendance: 1 Oct 2026 to 10 Oct 2026, all 12 students each day,
-- marked by admin 1 (warden). 10 days x 12 students = 120 rows.
-- ---------------------------------------------------------------------
-- 2026-10-01
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-01', 'Present', 1),
  (102, '2026-10-01', 'Present', 1),
  (103, '2026-10-01', 'Present', 1),
  (104, '2026-10-01', 'Present', 1),
  (105, '2026-10-01', 'Present', 1),
  (106, '2026-10-01', 'Present', 1),
  (107, '2026-10-01', 'Present', 1),
  (108, '2026-10-01', 'Absent', 1),
  (109, '2026-10-01', 'Present', 1),
  (110, '2026-10-01', 'Present', 1),
  (111, '2026-10-01', 'Present', 1),
  (112, '2026-10-01', 'Present', 1);
-- 2026-10-02
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-02', 'Present', 1),
  (102, '2026-10-02', 'Present', 1),
  (103, '2026-10-02', 'Present', 1),
  (104, '2026-10-02', 'Absent', 1),
  (105, '2026-10-02', 'Present', 1),
  (106, '2026-10-02', 'Present', 1),
  (107, '2026-10-02', 'Present', 1),
  (108, '2026-10-02', 'Present', 1),
  (109, '2026-10-02', 'Present', 1),
  (110, '2026-10-02', 'Present', 1),
  (111, '2026-10-02', 'Present', 1),
  (112, '2026-10-02', 'Leave', 1);
-- 2026-10-03
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-03', 'Present', 1),
  (102, '2026-10-03', 'Present', 1),
  (103, '2026-10-03', 'Leave', 1),
  (104, '2026-10-03', 'Present', 1),
  (105, '2026-10-03', 'Present', 1),
  (106, '2026-10-03', 'Present', 1),
  (107, '2026-10-03', 'Present', 1),
  (108, '2026-10-03', 'Absent', 1),
  (109, '2026-10-03', 'Present', 1),
  (110, '2026-10-03', 'Absent', 1),
  (111, '2026-10-03', 'Present', 1),
  (112, '2026-10-03', 'Leave', 1);
-- 2026-10-04
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-04', 'Present', 1),
  (102, '2026-10-04', 'Present', 1),
  (103, '2026-10-04', 'Present', 1),
  (104, '2026-10-04', 'Absent', 1),
  (105, '2026-10-04', 'Present', 1),
  (106, '2026-10-04', 'Present', 1),
  (107, '2026-10-04', 'Leave', 1),
  (108, '2026-10-04', 'Absent', 1),
  (109, '2026-10-04', 'Present', 1),
  (110, '2026-10-04', 'Present', 1),
  (111, '2026-10-04', 'Present', 1),
  (112, '2026-10-04', 'Present', 1);
-- 2026-10-05
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-05', 'Present', 1),
  (102, '2026-10-05', 'Present', 1),
  (103, '2026-10-05', 'Present', 1),
  (104, '2026-10-05', 'Present', 1),
  (105, '2026-10-05', 'Present', 1),
  (106, '2026-10-05', 'Absent', 1),
  (107, '2026-10-05', 'Leave', 1),
  (108, '2026-10-05', 'Present', 1),
  (109, '2026-10-05', 'Present', 1),
  (110, '2026-10-05', 'Present', 1),
  (111, '2026-10-05', 'Present', 1),
  (112, '2026-10-05', 'Present', 1);
-- 2026-10-06
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-06', 'Present', 1),
  (102, '2026-10-06', 'Present', 1),
  (103, '2026-10-06', 'Present', 1),
  (104, '2026-10-06', 'Absent', 1),
  (105, '2026-10-06', 'Present', 1),
  (106, '2026-10-06', 'Present', 1),
  (107, '2026-10-06', 'Present', 1),
  (108, '2026-10-06', 'Leave', 1),
  (109, '2026-10-06', 'Present', 1),
  (110, '2026-10-06', 'Present', 1),
  (111, '2026-10-06', 'Present', 1),
  (112, '2026-10-06', 'Absent', 1);
-- 2026-10-07
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-07', 'Present', 1),
  (102, '2026-10-07', 'Present', 1),
  (103, '2026-10-07', 'Present', 1),
  (104, '2026-10-07', 'Present', 1),
  (105, '2026-10-07', 'Present', 1),
  (106, '2026-10-07', 'Present', 1),
  (107, '2026-10-07', 'Present', 1),
  (108, '2026-10-07', 'Present', 1),
  (109, '2026-10-07', 'Present', 1),
  (110, '2026-10-07', 'Present', 1),
  (111, '2026-10-07', 'Present', 1),
  (112, '2026-10-07', 'Present', 1);
-- 2026-10-08
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-08', 'Present', 1),
  (102, '2026-10-08', 'Present', 1),
  (103, '2026-10-08', 'Present', 1),
  (104, '2026-10-08', 'Present', 1),
  (105, '2026-10-08', 'Present', 1),
  (106, '2026-10-08', 'Present', 1),
  (107, '2026-10-08', 'Present', 1),
  (108, '2026-10-08', 'Absent', 1),
  (109, '2026-10-08', 'Present', 1),
  (110, '2026-10-08', 'Present', 1),
  (111, '2026-10-08', 'Absent', 1),
  (112, '2026-10-08', 'Present', 1);
-- 2026-10-09
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-09', 'Present', 1),
  (102, '2026-10-09', 'Absent', 1),
  (103, '2026-10-09', 'Present', 1),
  (104, '2026-10-09', 'Absent', 1),
  (105, '2026-10-09', 'Present', 1),
  (106, '2026-10-09', 'Present', 1),
  (107, '2026-10-09', 'Present', 1),
  (108, '2026-10-09', 'Present', 1),
  (109, '2026-10-09', 'Present', 1),
  (110, '2026-10-09', 'Present', 1),
  (111, '2026-10-09', 'Present', 1),
  (112, '2026-10-09', 'Present', 1);
-- 2026-10-10
INSERT INTO attendance (student_id, att_date, status, marked_by) VALUES
  (101, '2026-10-10', 'Present', 1),
  (102, '2026-10-10', 'Present', 1),
  (103, '2026-10-10', 'Present', 1),
  (104, '2026-10-10', 'Present', 1),
  (105, '2026-10-10', 'Present', 1),
  (106, '2026-10-10', 'Present', 1),
  (107, '2026-10-10', 'Present', 1),
  (108, '2026-10-10', 'Present', 1),
  (109, '2026-10-10', 'Leave', 1),
  (110, '2026-10-10', 'Present', 1),
  (111, '2026-10-10', 'Present', 1),
  (112, '2026-10-10', 'Present', 1);

-- ---------------------------------------------------------------------
-- Quick check after loading (expected: 1, 5, 12, 120)
-- ---------------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM admin)      AS admins,
       (SELECT COUNT(*) FROM room)       AS rooms,
       (SELECT COUNT(*) FROM student)    AS students,
       (SELECT COUNT(*) FROM attendance) AS attendance_rows;
       
USE hostel_db;
SELECT * FROM v_defaulters;
