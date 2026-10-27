"""
student.py
----------
Module A: Student Management.
One function per operation: add, display, update, delete, search.

Validation is done TWICE on purpose:
  1. In Python (here), to give the warden a clear message straight away.
  2. In MySQL (schema.sql CHECK / UNIQUE / triggers), as the final safety net,
     so bad data cannot get in even if someone bypasses this program.
"""

from datetime import date, datetime
from mysql.connector import Error
from tabulate import tabulate

from db import fetch_all, fetch_one, execute, friendly_error

MAX_STUDENTS = 100

# Columns the warden may update: menu number -> (column name, label).
# This list is also a WHITELIST: column names cannot be sent as %s
# placeholders, so we only ever put names from this list into the SQL.
UPDATABLE_FIELDS = {
    "1":  ("full_name",      "Full name"),
    "2":  ("gender",         "Gender (M/F/O)"),
    "3":  ("date_of_birth",  "Date of birth (YYYY-MM-DD)"),
    "4":  ("phone",          "Phone (10 digits)"),
    "5":  ("guardian_name",  "Guardian name"),
    "6":  ("guardian_phone", "Guardian phone (10 digits)"),
    "7":  ("address",        "Address"),
    "8":  ("course",         "Course"),
    "9":  ("year_of_study",  "Year of study (1-5)"),
    "10": ("room_no",        "Room number"),
    "11": ("admission_date", "Admission date (YYYY-MM-DD)"),
}


# =====================================================================
# Validation helpers
# Each returns (True, cleaned_value) or (False, error_message).
# =====================================================================

def validate_text(value, label):
    value = value.strip()
    if value == "":
        return False, f"{label} cannot be empty."
    return True, value


def validate_phone(value):
    value = value.strip()
    if len(value) != 10 or not value.isdigit():
        return False, "Phone number must be exactly 10 digits."
    return True, value


def validate_date(value, label):
    """Accept only a real calendar date in YYYY-MM-DD, not in the future."""
    try:
        d = datetime.strptime(value.strip(), "%Y-%m-%d").date()
    except ValueError:
        return False, f"{label} must be a valid date in YYYY-MM-DD format."
    if d > date.today():
        return False, f"{label} cannot be in the future."
    return True, d


def validate_gender(value):
    value = value.strip().upper()
    if value not in ("M", "F", "O"):
        return False, "Gender must be M, F or O."
    return True, value


def validate_year(value):
    if not value.strip().isdigit() or not 1 <= int(value) <= 5:
        return False, "Year of study must be a number from 1 to 5."
    return True, int(value)


def validate_student_id(value):
    if not value.strip().isdigit() or int(value) <= 0:
        return False, "Student ID must be a positive whole number."
    return True, int(value)


def validate_field(column, value):
    """Pick the right validator for a column name (used by add and update)."""
    if column in ("phone", "guardian_phone"):
        return validate_phone(value)
    if column == "date_of_birth":
        return validate_date(value, "Date of birth")
    if column == "admission_date":
        return validate_date(value, "Admission date")
    if column == "gender":
        return validate_gender(value)
    if column == "year_of_study":
        return validate_year(value)
    if column == "room_no":
        ok, v = validate_text(value, "Room number")
        return ok, (v.upper() if ok else v)
    return validate_text(value, column.replace("_", " ").capitalize())


def ask(prompt, column):
    """Keep asking until the input passes validation, then return it."""
    while True:
        ok, result = validate_field(column, input(prompt))
        if ok:
            return result
        print("  ->", result)


# =====================================================================
# Small database lookups used by the operations below
# =====================================================================

def count_students():
    # COUNT(*) returns the number of rows in the student table.
    return fetch_one("SELECT COUNT(*) FROM student")[0]


def student_exists(student_id):
    # Returns True if a row with this primary key exists.
    return fetch_one("SELECT 1 FROM student WHERE student_id = %s",
                     (student_id,)) is not None


def show_available_rooms():
    # Uses the view from schema.sql; only rooms with a free bed are shown.
    cols, rows = fetch_all(
        "SELECT room_no, floor, capacity, occupied, free_beds "
        "FROM v_room_occupancy WHERE free_beds > 0 ORDER BY room_no")
    if rows:
        print("\nRooms with free beds:")
        print(tabulate(rows, headers=cols, tablefmt="github"))
    else:
        print("\nNo free beds in any room.")
    return [r[0] for r in rows]          # list of room numbers with space


def print_students(cols, rows):
    if rows:
        print(tabulate(rows, headers=cols, tablefmt="github"))
        print(f"({len(rows)} record(s))")
    else:
        print("No matching students found.")


# =====================================================================
# 1. ADD STUDENT
# =====================================================================

def add_student():
    print("\n--- Add New Student ---")

    # Rule: maximum 100 students. Checked here for a clear message;
    # trigger trg_student_limit blocks it in MySQL as well.
    total = count_students()
    if total >= MAX_STUDENTS:
        print(f"Registration blocked: the hostel already has {MAX_STUDENTS} students.")
        return
    print(f"Students currently registered: {total}/{MAX_STUDENTS}")

    free_rooms = show_available_rooms()
    if not free_rooms:
        print("Registration blocked: every room is full.")
        return

    # Student ID: must be a positive number and not already used.
    while True:
        ok, sid = validate_student_id(input("Student ID: "))
        if not ok:
            print("  ->", sid)
        elif student_exists(sid):
            print(f"  -> Student ID {sid} already exists. Choose another.")
        else:
            break

    name      = ask("Full name: ", "full_name")
    gender    = ask("Gender (M/F/O): ", "gender")
    dob       = ask("Date of birth (YYYY-MM-DD): ", "date_of_birth")
    phone     = ask("Phone (10 digits): ", "phone")
    g_name    = ask("Guardian name: ", "guardian_name")
    g_phone   = ask("Guardian phone (10 digits): ", "guardian_phone")
    address   = ask("Address: ", "address")
    course    = ask("Course: ", "course")
    year      = ask("Year of study (1-5): ", "year_of_study")

    while True:
        room = ask("Room number: ", "room_no")
        if room in free_rooms:
            break
        print(f"  -> Room {room} does not exist or is full. Pick from the list above.")

    while True:
        adm = ask("Admission date (YYYY-MM-DD): ", "admission_date")
        if adm > dob:
            break
        print("  -> Admission date must be after date of birth.")

    # INSERT with %s placeholders: values are passed separately (safe from SQL injection).
    sql = ("INSERT INTO student (student_id, full_name, gender, date_of_birth, phone, "
           "guardian_name, guardian_phone, address, course, year_of_study, room_no, "
           "admission_date) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)")
    try:
        execute(sql, (sid, name, gender, dob, phone, g_name, g_phone,
                      address, course, year, room, adm))
        print(f"Student {sid} ({name}) added to room {room}.")
    except Error as e:
        print("Could not add student:", friendly_error(e))


# =====================================================================
# 2. DISPLAY ALL STUDENTS
# =====================================================================

def display_all_students():
    print("\n--- All Students ---")
    # Selects the most useful columns, sorted by ID. TIMESTAMPDIFF gives age
    # in years from date_of_birth (age is derived, so it is never stored).
    cols, rows = fetch_all(
        "SELECT student_id AS ID, full_name AS Name, gender AS G, "
        "TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS Age, phone AS Phone, "
        "course AS Course, year_of_study AS Yr, room_no AS Room "
        "FROM student ORDER BY student_id")
    print_students(cols, rows)


def show_student_details(student_id):
    """Print every column of one student. Returns False if not found."""
    cols, rows = fetch_all("SELECT * FROM student WHERE student_id = %s",
                           (student_id,))
    if not rows:
        print(f"No student with ID {student_id}.")
        return False
    # Show as two columns (field | value), easier to read than one wide row.
    print(tabulate(list(zip(cols, rows[0])), headers=["Field", "Value"], tablefmt="github"))
    return True


def ask_existing_id():
    """Ask for a student ID; return it if valid and existing, else None."""
    ok, sid = validate_student_id(input("Enter student ID: "))
    if not ok:
        print("  ->", sid)
        return None
    if not show_student_details(sid):
        return None
    return sid


# =====================================================================
# 3. UPDATE STUDENT (warden chooses one field)
# =====================================================================

def update_student():
    print("\n--- Update Student ---")
    sid = ask_existing_id()
    if sid is None:
        return

    print("\nWhich field do you want to change?")
    for num, (_, label) in UPDATABLE_FIELDS.items():
        print(f"  {num:>2}. {label}")
    choice = input("Choice: ").strip()
    if choice not in UPDATABLE_FIELDS:
        print("Invalid choice. Nothing changed.")
        return

    column, label = UPDATABLE_FIELDS[choice]
    if column == "room_no":
        show_available_rooms()
    new_value = ask(f"New {label}: ", column)

    # The column name comes only from our whitelist, never from user typing.
    # The value still goes through %s. If the room is full, trigger
    # trg_room_capacity_update raises an error that we catch below.
    sql = f"UPDATE student SET {column} = %s WHERE student_id = %s"
    try:
        execute(sql, (new_value, sid))
        print(f"{label} updated for student {sid}.")
    except Error as e:
        print("Could not update:", friendly_error(e))


# =====================================================================
# 4. DELETE STUDENT (with confirmation)
# =====================================================================

def delete_student():
    print("\n--- Delete Student ---")
    sid = ask_existing_id()
    if sid is None:
        return

    # Tell the warden how much attendance will also go (ON DELETE CASCADE).
    att_count = fetch_one("SELECT COUNT(*) FROM attendance WHERE student_id = %s",
                          (sid,))[0]
    print(f"\nThis will also delete {att_count} attendance record(s) of this student.")
    confirm = input("Type YES to confirm delete: ").strip()
    if confirm != "YES":
        print("Delete cancelled.")
        return

    try:
        # DELETE by primary key; attendance rows are removed by CASCADE.
        execute("DELETE FROM student WHERE student_id = %s", (sid,))
        print(f"Student {sid} deleted.")
    except Error as e:
        print("Could not delete:", friendly_error(e))


# =====================================================================
# 5. SEARCH (by ID or by partial name)
# =====================================================================

def search_by_id():
    ok, sid = validate_student_id(input("Enter student ID: "))
    if not ok:
        print("  ->", sid)
        return
    show_student_details(sid)


def search_by_name():
    text = input("Enter full or part of the name: ").strip()
    if text == "":
        print("  -> Please type at least one letter.")
        return
    # LIKE '%text%' matches the text anywhere in the name ("avi" finds "Ravi").
    # The % signs are added to the VALUE, so the placeholder stays safe.
    cols, rows = fetch_all(
        "SELECT student_id AS ID, full_name AS Name, phone AS Phone, "
        "course AS Course, room_no AS Room "
        "FROM student WHERE full_name LIKE %s ORDER BY full_name",
        (f"%{text}%",))
    print_students(cols, rows)


def search_student():
    print("\n--- Search Student ---")
    print("  1. By student ID")
    print("  2. By name (partial match)")
    choice = input("Choice: ").strip()
    if choice == "1":
        search_by_id()
    elif choice == "2":
        search_by_name()
    else:
        print("Invalid choice.")


# =====================================================================
# Module A menu (called from main.py)
# =====================================================================

def student_menu():
    actions = {
        "1": add_student,
        "2": display_all_students,
        "3": update_student,
        "4": delete_student,
        "5": search_student,
    }
    while True:
        print("\n======= STUDENT MANAGEMENT =======")
        print("  1. Add student")
        print("  2. Display all students")
        print("  3. Update student")
        print("  4. Delete student")
        print("  5. Search student")
        print("  0. Back to main menu")
        choice = input("Choice: ").strip()
        if choice == "0":
            return
        action = actions.get(choice)
        if action is None:
            print("Invalid choice, try again.")
            continue
        try:
            action()
        except Error as e:                 # e.g. MySQL stopped mid-session
            print("Database problem:", friendly_error(e))
