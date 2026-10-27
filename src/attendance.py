"""
attendance.py
-------------
Module B: Attendance System.
One function per operation: register, mark, correct, view (date / student /
month), percentage, defaulters.

How a student is "registered for attendance":
  Every row in the attendance table has student_id as a FOREIGN KEY to the
  student table. So every student in the student table is automatically on
  the attendance register, and attendance can never be saved for a student
  who does not exist.

Database rules that protect attendance (from schema.sql):
  UNIQUE(student_id, att_date)   -> no duplicate entry for the same day
  CHECK status IN (...)          -> only Present / Absent / Leave
  ON DELETE CASCADE              -> deleting a student removes their attendance
"""

from datetime import date, datetime
from mysql.connector import Error
from tabulate import tabulate

from db import fetch_all, fetch_one, execute, execute_many, friendly_error

DEFAULTER_LIMIT = 75     # percentage below which a student is a defaulter

# Short keys the warden types while marking -> value stored in the database
STATUS_KEYS = {"P": "Present", "A": "Absent", "L": "Leave"}


# =====================================================================
# Input helpers
# =====================================================================

def ask_date(prompt="Date (YYYY-MM-DD, Enter = today): "):
    """Return a valid date that is not in the future, or None if invalid."""
    text = input(prompt).strip()
    if text == "":
        return date.today()
    try:
        d = datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        print("  -> Invalid date. Use YYYY-MM-DD, for example 2026-10-11.")
        return None
    if d > date.today():
        print("  -> Attendance cannot be marked or viewed for a future date.")
        return None
    return d


def ask_month():
    """
    Ask for a month as YYYY-MM. Return (first_day, first_day_of_next_month),
    or None if invalid. Using a date RANGE (>= first AND < next) instead of
    MONTH(att_date) lets MySQL use the index on att_date.
    """
    text = input("Month (YYYY-MM, Enter = this month): ").strip()
    if text == "":
        text = date.today().strftime("%Y-%m")
    try:
        first = datetime.strptime(text + "-01", "%Y-%m-%d").date()
    except ValueError:
        print("  -> Invalid month. Use YYYY-MM, for example 2026-10.")
        return None
    if first.month == 12:
        next_first = date(first.year + 1, 1, 1)
    else:
        next_first = date(first.year, first.month + 1, 1)
    return first, next_first


def ask_student_id():
    text = input("Student ID: ").strip()
    if not text.isdigit():
        print("  -> Student ID must be a number.")
        return None
    row = fetch_one("SELECT student_id, full_name FROM student WHERE student_id = %s",
                    (int(text),))
    if row is None:
        print(f"  -> No student with ID {text}.")
        return None
    return row                       # (student_id, full_name)


def print_table(cols, rows, empty_msg="No records found."):
    if rows:
        print(tabulate(rows, headers=cols, tablefmt="github"))
        print(f"({len(rows)} row(s))")
    else:
        print(empty_msg)


# =====================================================================
# 1. ATTENDANCE REGISTER (students linked to attendance through the FK)
# =====================================================================

def show_register():
    print("\n--- Attendance Register ---")
    # LEFT JOIN keeps students with no attendance yet (Days marked = 0).
    cols, rows = fetch_all(
        "SELECT s.student_id AS ID, s.full_name AS Name, s.room_no AS Room, "
        "COUNT(a.attendance_id) AS `Days marked`, MAX(a.att_date) AS `Last marked` "
        "FROM student s LEFT JOIN attendance a ON a.student_id = s.student_id "
        "GROUP BY s.student_id, s.full_name, s.room_no "
        "ORDER BY s.student_id")
    print("Every student in the Student table is on this register automatically")
    print("(attendance.student_id is a FOREIGN KEY to student.student_id).\n")
    print_table(cols, rows, "No students registered yet.")


# =====================================================================
# 2. MARK DAILY ATTENDANCE for all students on one date
# =====================================================================

def get_unmarked_students(att_date):
    """
    Students admitted on or before this date who have NO attendance row
    for it yet. NOT EXISTS is a correlated subquery: for each student it
    checks whether a matching attendance row exists.
    """
    _, rows = fetch_all(
        "SELECT s.student_id, s.full_name, s.room_no FROM student s "
        "WHERE s.admission_date <= %s "
        "AND NOT EXISTS (SELECT 1 FROM attendance a "
        "                WHERE a.student_id = s.student_id AND a.att_date = %s) "
        "ORDER BY s.room_no, s.student_id",
        (att_date, att_date))
    return rows


def mark_attendance(admin_id):
    print("\n--- Mark Daily Attendance ---")
    att_date = ask_date()
    if att_date is None:
        return

    # How many are already marked for this date? (for a clear message)
    already = fetch_one("SELECT COUNT(*) FROM attendance WHERE att_date = %s",
                        (att_date,))[0]
    pending = get_unmarked_students(att_date)

    if not pending:
        if already:
            print(f"Attendance for {att_date} is already marked for all "
                  f"{already} student(s). Duplicate entries are not allowed.")
            print("Use 'Correct an attendance entry' to change a status.")
        else:
            print("No students were admitted on or before this date.")
        return
    if already:
        print(f"{already} student(s) already marked for {att_date}. "
              f"Marking the remaining {len(pending)}.")

    print(f"\nMarking {att_date.strftime('%A, %d %b %Y')}")
    print("Type P = Present, A = Absent, L = Leave.  Press Enter for Present.\n")

    entries = []     # list of (student_id, att_date, status, marked_by)
    for sid, name, room in pending:
        while True:
            key = input(f"  [{room}] {sid} {name:<20}: ").strip().upper() or "P"
            if key in STATUS_KEYS:
                entries.append((sid, att_date, STATUS_KEYS[key], admin_id))
                break
            print("    -> Type P, A or L (or Enter for Present).")

    # Show a summary and ask before saving.
    counts = {s: sum(1 for e in entries if e[2] == s) for s in STATUS_KEYS.values()}
    print(f"\nSummary: Present {counts['Present']}, Absent {counts['Absent']}, "
          f"Leave {counts['Leave']}  (total {len(entries)})")
    if input("Save this attendance? (Y/N): ").strip().upper() != "Y":
        print("Not saved.")
        return

    # One INSERT per student, all inside ONE transaction (all or nothing).
    # If anyone else marked the same student meanwhile, UNIQUE(student_id,
    # att_date) raises error 1062 and the whole batch is rolled back.
    sql = ("INSERT INTO attendance (student_id, att_date, status, marked_by) "
           "VALUES (%s, %s, %s, %s)")
    try:
        execute_many(sql, entries)
        print(f"Attendance saved for {len(entries)} student(s) on {att_date}.")
    except Error as e:
        print("Nothing was saved:", friendly_error(e))


# =====================================================================
# 3. CORRECT ONE ENTRY (because duplicates are blocked, mistakes are
#    fixed with UPDATE instead of a second INSERT)
# =====================================================================

def correct_attendance(admin_id):
    print("\n--- Correct an Attendance Entry ---")
    student = ask_student_id()
    if student is None:
        return
    att_date = ask_date("Date to correct (YYYY-MM-DD): ")
    if att_date is None:
        return

    row = fetch_one("SELECT status FROM attendance WHERE student_id = %s AND att_date = %s",
                    (student[0], att_date))
    if row is None:
        print(f"  -> No attendance entry for {student[1]} on {att_date}. Mark it first.")
        return
    print(f"Current status of {student[1]} on {att_date}: {row[0]}")

    key = input("New status (P/A/L): ").strip().upper()
    if key not in STATUS_KEYS:
        print("  -> Invalid status. Nothing changed.")
        return
    if STATUS_KEYS[key] == row[0]:
        print("  -> Same as the current status. Nothing changed.")
        return
    # UPDATE the existing row found by its natural key (student_id, att_date).
    try:
        execute("UPDATE attendance SET status = %s, marked_by = %s "
                "WHERE student_id = %s AND att_date = %s",
                (STATUS_KEYS[key], admin_id, student[0], att_date))
        print(f"Updated: {row[0]} -> {STATUS_KEYS[key]}")
    except Error as e:
        print("Could not update:", friendly_error(e))


# =====================================================================
# 4a. VIEW BY DATE
# =====================================================================

def view_by_date():
    print("\n--- Attendance by Date ---")
    att_date = ask_date()
    if att_date is None:
        return
    # INNER JOIN: only students who have an entry on that date.
    cols, rows = fetch_all(
        "SELECT s.student_id AS ID, s.full_name AS Name, s.room_no AS Room, "
        "a.status AS Status "
        "FROM attendance a JOIN student s ON s.student_id = a.student_id "
        "WHERE a.att_date = %s ORDER BY s.room_no, s.student_id",
        (att_date,))
    print_table(cols, rows, f"No attendance marked for {att_date}.")
    if rows:
        # GROUP BY status gives one count per status for that day.
        _, summary = fetch_all(
            "SELECT status, COUNT(*) FROM attendance WHERE att_date = %s "
            "GROUP BY status ORDER BY status", (att_date,))
        print("Day summary: " + ", ".join(f"{s} {n}" for s, n in summary))


# =====================================================================
# 4b. VIEW BY STUDENT
# =====================================================================

def view_by_student():
    print("\n--- Attendance by Student ---")
    student = ask_student_id()
    if student is None:
        return
    # All entries for one student, newest first. DAYNAME shows the weekday.
    cols, rows = fetch_all(
        "SELECT att_date AS Date, DAYNAME(att_date) AS Day, status AS Status "
        "FROM attendance WHERE student_id = %s ORDER BY att_date DESC",
        (student[0],))
    print(f"Student: {student[0]} {student[1]}")
    print_table(cols, rows, "No attendance marked for this student yet.")
    if rows:
        # Stored FUNCTION from schema.sql, called inside a SELECT.
        pct = fetch_one("SELECT fn_attendance_pct(%s)", (student[0],))[0]
        flag = "  (DEFAULTER)" if pct is not None and pct < DEFAULTER_LIMIT else ""
        print(f"Attendance percentage: {pct}%{flag}")


# =====================================================================
# 4c. VIEW BY MONTH
# =====================================================================

def view_by_month():
    print("\n--- Monthly Attendance Report ---")
    month = ask_month()
    if month is None:
        return
    first, next_first = month
    # Per-student counts for the month. SUM(condition) counts the true rows.
    # The date range uses the index on att_date.
    cols, rows = fetch_all(
        "SELECT s.student_id AS ID, s.full_name AS Name, "
        "COUNT(*) AS Days, "
        "SUM(a.status = 'Present') AS P, "
        "SUM(a.status = 'Absent')  AS A, "
        "SUM(a.status = 'Leave')   AS L, "
        "ROUND(SUM(a.status = 'Present') * 100 / COUNT(*), 2) AS Pct "
        "FROM attendance a JOIN student s ON s.student_id = a.student_id "
        "WHERE a.att_date >= %s AND a.att_date < %s "
        "GROUP BY s.student_id, s.full_name ORDER BY s.student_id",
        (first, next_first))
    print(f"Month: {first.strftime('%B %Y')}")
    print_table(cols, rows, "No attendance marked in this month.")
    if rows:
        days = fetch_one("SELECT COUNT(DISTINCT att_date) FROM attendance "
                         "WHERE att_date >= %s AND att_date < %s",
                         (first, next_first))[0]
        print(f"Working days with attendance this month: {days}")


# =====================================================================
# 5. ATTENDANCE PERCENTAGE (overall, from the view)
# =====================================================================

def show_percentages():
    print("\n--- Attendance Percentage (all students) ---")
    print("Formula: (days present / total working days marked) x 100\n")
    # v_attendance_summary is the VIEW from schema.sql. Students with no
    # attendance yet show an empty percentage (NULL).
    cols, rows = fetch_all(
        "SELECT student_id AS ID, full_name AS Name, total_days AS Days, "
        "present_days AS P, absent_days AS A, leave_days AS L, "
        "attendance_pct AS Pct "
        "FROM v_attendance_summary ORDER BY student_id")
    print_table(cols, rows, "No students found.")


# =====================================================================
# 6. DEFAULTER LIST (below 75%)
# =====================================================================

def show_defaulters():
    print(f"\n--- Defaulter List (below {DEFAULTER_LIMIT}%) ---")
    # v_defaulters is a view built on top of v_attendance_summary.
    cols, rows = fetch_all(
        "SELECT student_id AS ID, full_name AS Name, room_no AS Room, "
        "total_days AS Days, present_days AS Present, attendance_pct AS Pct "
        "FROM v_defaulters ORDER BY attendance_pct, student_id")
    print_table(cols, rows, "No defaulters. Every student is at or above 75%.")


# =====================================================================
# Module B menu (called from main.py)
# =====================================================================

def attendance_menu(admin_id):
    while True:
        print("\n========== ATTENDANCE ==========")
        print("  1. Show attendance register")
        print("  2. Mark daily attendance")
        print("  3. Correct an attendance entry")
        print("  4. View by date")
        print("  5. View by student")
        print("  6. View by month")
        print("  7. Attendance percentage (all students)")
        print("  8. Defaulter list (below 75%)")
        print("  0. Back to main menu")
        choice = input("Choice: ").strip()
        try:
            if choice == "1":
                show_register()
            elif choice == "2":
                mark_attendance(admin_id)
            elif choice == "3":
                correct_attendance(admin_id)
            elif choice == "4":
                view_by_date()
            elif choice == "5":
                view_by_student()
            elif choice == "6":
                view_by_month()
            elif choice == "7":
                show_percentages()
            elif choice == "8":
                show_defaulters()
            elif choice == "0":
                return
            else:
                print("Invalid choice, try again.")
        except Error as e:
            print("Database problem:", friendly_error(e))