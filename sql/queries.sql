-- =====================================================================
-- queries.sql
-- Sample queries for the viva / report. READ-ONLY: nothing here changes data.
-- Expected outputs are for the fresh seed data (schema.sql + seed.sql).
--
-- Run one query at a time: in Workbench place the cursor on a query and
-- press Ctrl+Enter (the lightning bolt with the I-cursor).
--
-- Concepts covered:
--   Q1-Q2   JOIN (INNER, LEFT)
--   Q3-Q5   GROUP BY, aggregates (COUNT, MIN, MAX, AVG)
--   Q6      HAVING
--   Q7-Q9   Subqueries (scalar, IN, NOT EXISTS / correlated)
--   Q10-Q12 Date-wise and room-wise reports, ORDER BY + LIMIT
--   Q13-Q15 Views + JOIN, HAVING on JOIN, subquery with MIN
--   Q16-Q17 Using the views and the stored function
-- =====================================================================
USE hostel_db;


-- ---------------------------------------------------------------------
-- Q1. INNER JOIN: each student with the floor of their room.
-- floor is stored only in room (3NF), so we JOIN to get it.
-- ---------------------------------------------------------------------
SELECT s.student_id, s.full_name, s.room_no, r.floor
FROM student s
INNER JOIN room r ON r.room_no = s.room_no
ORDER BY s.student_id;
-- Expected: 12 rows. First three:
-- 101 | Ravi Patil   | A101 | 1
-- 102 | Amit Kale    | A101 | 1
-- 103 | Sagar Jadhav | A101 | 1


-- ---------------------------------------------------------------------
-- Q2. LEFT JOIN: every room with the number of students in it.
-- LEFT JOIN keeps B202 even though no student lives there.
-- (An INNER JOIN would drop it.)
-- ---------------------------------------------------------------------
SELECT r.room_no, r.capacity, COUNT(s.student_id) AS occupied
FROM room r
LEFT JOIN student s ON s.room_no = r.room_no
GROUP BY r.room_no, r.capacity
ORDER BY r.room_no;
-- Expected:
-- A101 | 4 | 4
-- A102 | 4 | 3
-- A103 | 2 | 1
-- B201 | 4 | 4
-- B202 | 4 | 0


-- ---------------------------------------------------------------------
-- Q3. GROUP BY + COUNT: number of students per course.
-- ---------------------------------------------------------------------
SELECT course, COUNT(*) AS students
FROM student
GROUP BY course
ORDER BY students DESC, course;
-- Expected:
-- B.Tech AIML       | 3
-- B.Tech CSE        | 3
-- B.Tech Civil      | 2
-- B.Tech ENTC       | 2
-- B.Tech Electrical | 1
-- B.Tech Mech       | 1


-- ---------------------------------------------------------------------
-- Q4. GROUP BY on two separate columns: gender split and year split.
-- ---------------------------------------------------------------------
SELECT gender, COUNT(*) AS students
FROM student
GROUP BY gender
ORDER BY gender;
-- Expected:  F | 4    M | 8

SELECT year_of_study, COUNT(*) AS students
FROM student
GROUP BY year_of_study
ORDER BY year_of_study;
-- Expected:  1 | 3    2 | 4    3 | 3    4 | 2


-- ---------------------------------------------------------------------
-- Q5. Aggregates: overall attendance statistics from the view.
-- ---------------------------------------------------------------------
SELECT COUNT(*)                     AS students,
       MIN(attendance_pct)          AS lowest_pct,
       MAX(attendance_pct)          AS highest_pct,
       ROUND(AVG(attendance_pct),2) AS average_pct
FROM v_attendance_summary;
-- Expected:  12 | 50.00 | 100.00 | 83.33


-- ---------------------------------------------------------------------
-- Q6. HAVING: rooms that are completely full.
-- WHERE filters rows BEFORE grouping; HAVING filters groups AFTER.
-- A condition on COUNT(...) must therefore go in HAVING.
-- ---------------------------------------------------------------------
SELECT r.room_no, r.capacity, COUNT(s.student_id) AS occupied
FROM room r
JOIN student s ON s.room_no = r.room_no
GROUP BY r.room_no, r.capacity
HAVING COUNT(s.student_id) = r.capacity;
-- Expected:
-- A101 | 4 | 4
-- B201 | 4 | 4


-- ---------------------------------------------------------------------
-- Q7. Scalar subquery: students above the average attendance.
-- The inner SELECT returns ONE value (83.33) used by the outer WHERE.
-- ---------------------------------------------------------------------
SELECT student_id, full_name, attendance_pct
FROM v_attendance_summary
WHERE attendance_pct > (SELECT AVG(attendance_pct) FROM v_attendance_summary)
ORDER BY attendance_pct DESC, student_id;
-- Expected (8 rows):
-- 101 | Ravi Patil     | 100.00
-- 105 | Omkar Pawar    | 100.00
-- 102 | Amit Kale      |  90.00
-- 103 | Sagar Jadhav   |  90.00
-- 106 | Rohit Mane     |  90.00
-- 109 | Sneha Kulkarni |  90.00
-- 110 | Pooja Deshmukh |  90.00
-- 111 | Priya More     |  90.00


-- ---------------------------------------------------------------------
-- Q8. Subquery with IN: who was absent on 4 Oct 2026?
-- The inner query returns a LIST of student_ids.
-- ---------------------------------------------------------------------
SELECT student_id, full_name
FROM student
WHERE student_id IN (SELECT student_id
                     FROM attendance
                     WHERE att_date = '2026-10-04' AND status = 'Absent');
-- Expected:
-- 104 | Pranav Shinde
-- 108 | Nikhil Chavan


-- ---------------------------------------------------------------------
-- Q9. Correlated subquery with NOT EXISTS: students never absent.
-- "Correlated" = the inner query uses s.student_id from the outer row,
-- so it runs once for each student.
-- ---------------------------------------------------------------------
SELECT s.student_id, s.full_name
FROM student s
WHERE NOT EXISTS (SELECT 1
                  FROM attendance a
                  WHERE a.student_id = s.student_id AND a.status = 'Absent')
ORDER BY s.student_id;
-- Expected (5 rows): 101 Ravi Patil, 103 Sagar Jadhav, 105 Omkar Pawar,
--                    107 Vishal Gaikwad, 109 Sneha Kulkarni


-- ---------------------------------------------------------------------
-- Q10. Date-wise report: present / absent / leave count for each day.
-- SUM(condition) counts the rows where the condition is true.
-- ---------------------------------------------------------------------
SELECT att_date,
       SUM(status = 'Present') AS present,
       SUM(status = 'Absent')  AS absent,
       SUM(status = 'Leave')   AS on_leave,
       ROUND(SUM(status = 'Present') * 100 / COUNT(*), 2) AS present_pct
FROM attendance
GROUP BY att_date
ORDER BY att_date;
-- Expected:
-- 2026-10-01 | 11 | 1 | 0 |  91.67
-- 2026-10-02 | 10 | 1 | 1 |  83.33
-- 2026-10-03 |  8 | 2 | 2 |  66.67
-- 2026-10-04 |  9 | 2 | 1 |  75.00
-- 2026-10-05 | 10 | 1 | 1 |  83.33
-- 2026-10-06 |  9 | 2 | 1 |  75.00
-- 2026-10-07 | 12 | 0 | 0 | 100.00
-- 2026-10-08 | 10 | 2 | 0 |  83.33
-- 2026-10-09 | 10 | 2 | 0 |  83.33
-- 2026-10-10 | 11 | 0 | 1 |  91.67


-- ---------------------------------------------------------------------
-- Q11. Room-wise average attendance (GROUP BY on a view).
-- ---------------------------------------------------------------------
SELECT room_no, COUNT(*) AS students, ROUND(AVG(attendance_pct), 2) AS avg_pct
FROM v_attendance_summary
GROUP BY room_no
ORDER BY avg_pct, room_no;
-- Expected:
-- A103 | 1 | 50.00
-- A101 | 4 | 85.00
-- B201 | 4 | 85.00
-- A102 | 3 | 90.00


-- ---------------------------------------------------------------------
-- Q12. ORDER BY + LIMIT: top 3 students by attendance.
-- ---------------------------------------------------------------------
SELECT student_id, full_name, attendance_pct
FROM v_attendance_summary
ORDER BY attendance_pct DESC, student_id
LIMIT 3;
-- Expected:
-- 101 | Ravi Patil  | 100.00
-- 105 | Omkar Pawar | 100.00
-- 102 | Amit Kale   |  90.00


-- ---------------------------------------------------------------------
-- Q13. View + JOIN: defaulters with guardian contact
-- (the list a warden would use to call or SMS parents).
-- ---------------------------------------------------------------------
SELECT d.student_id, d.full_name, s.guardian_name, s.guardian_phone, d.attendance_pct
FROM v_defaulters d
JOIN student s ON s.student_id = d.student_id
ORDER BY d.attendance_pct;
-- Expected:
-- 108 | Nikhil Chavan   | Prakash Chavan    | 9822000108 | 50.00
-- 104 | Pranav Shinde   | Anil Shinde       | 9822000104 | 60.00
-- 112 | Anjali Salunkhe | Rajendra Salunkhe | 9822000112 | 70.00


-- ---------------------------------------------------------------------
-- Q14. JOIN + GROUP BY + HAVING: students with 2 or more leave days.
-- ---------------------------------------------------------------------
SELECT s.student_id, s.full_name, COUNT(*) AS leave_days
FROM attendance a
JOIN student s ON s.student_id = a.student_id
WHERE a.status = 'Leave'
GROUP BY s.student_id, s.full_name
HAVING COUNT(*) >= 2;
-- Expected:
-- 107 | Vishal Gaikwad  | 2
-- 112 | Anjali Salunkhe | 2


-- ---------------------------------------------------------------------
-- Q15. Subquery with MIN + derived attribute: the oldest student and age.
-- Age is computed, never stored (derived attribute).
-- ---------------------------------------------------------------------
SELECT student_id, full_name, date_of_birth,
       TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
FROM student
WHERE date_of_birth = (SELECT MIN(date_of_birth) FROM student);
-- Expected: 107 | Vishal Gaikwad | 2003-09-25 | 23  (age as of Oct 2026)


-- ---------------------------------------------------------------------
-- Q16. The three views directly.
-- ---------------------------------------------------------------------
SELECT * FROM v_attendance_summary;   -- 12 rows, percentages 50 to 100
SELECT * FROM v_defaulters;           -- 104, 108, 112
SELECT * FROM v_room_occupancy;       -- same counts as Q2, plus free_beds


-- ---------------------------------------------------------------------
-- Q17. Stored function inside a SELECT.
-- ---------------------------------------------------------------------
SELECT student_id, full_name, fn_attendance_pct(student_id) AS pct
FROM student
WHERE student_id IN (101, 104, 108);
-- Expected:
-- 101 | Ravi Patil    | 100.00
-- 104 | Pranav Shinde |  60.00
-- 108 | Nikhil Chavan |  50.00


-- ---------------------------------------------------------------------
-- Q18. Looking at the database objects (metadata).
-- ---------------------------------------------------------------------
SHOW TRIGGERS;                                         -- 3 triggers
SHOW INDEX FROM student;                               -- PRIMARY, uq_student_phone, fk index, idx_student_name
SHOW FUNCTION STATUS WHERE Db = 'hostel_db';           -- fn_attendance_pct
-- EXPLAIN shows how MySQL plans to run a query.
-- 'Ra%'  -> possible_keys lists idx_student_name (the index CAN be used).
-- '%vi%' -> possible_keys is NULL (a leading wildcard can never use it).
-- With only 12 rows MySQL may still choose a full scan for 'Ra%', because
-- reading 12 rows directly is cheaper; with thousands of rows it uses the index.
EXPLAIN SELECT * FROM student WHERE full_name LIKE 'Ra%';
EXPLAIN SELECT * FROM student WHERE full_name LIKE '%vi%';