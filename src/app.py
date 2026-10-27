"""
app.py
------
Flask web frontend. Run from the src folder:   python app.py
Then open http://127.0.0.1:5000
"""

from datetime import date
from functools import wraps

from flask import (Flask, render_template, request, redirect,
                   url_for, session, flash)
from mysql.connector import Error

from auth import hash_password
from db import fetch_all, fetch_one, execute, execute_many, friendly_error
from student import (validate_field, validate_student_id, validate_date,
                     count_students, student_exists, MAX_STUDENTS)

app = Flask(__name__)
app.secret_key = "change-this-to-something-random"

# Every editable column of the student table, in INSERT order.
FIELDS = ["full_name", "gender", "date_of_birth", "phone", "guardian_name",
          "guardian_phone", "address", "course", "year_of_study",
          "room_no", "admission_date"]

STATUSES = ("Present", "Absent", "Leave")
DEFAULTER_LIMIT = 75          # same 75% rule as v_defaulters in schema.sql


def login_required(view):
    """Redirect to the login page if the admin is not logged in."""
    @wraps(view)
    def wrapper(*args, **kwargs):
        if "admin_id" not in session:
            return redirect(url_for("login"))
        return view(*args, **kwargs)
    return wrapper


# ---------------------------------------------------------------------
# Login / logout / dashboard
# ---------------------------------------------------------------------

@app.route("/", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form["username"].strip()
        password = request.form["password"]
        try:
            admin = fetch_one(
                "SELECT admin_id, full_name FROM admin "
                "WHERE username = %s AND password_hash = %s",
                (username, hash_password(password)))
        except Exception as e:
            flash(f"Database error: {e}", "danger")
            return render_template("login.html")
        if admin:
            session["admin_id"] = admin[0]
            session["admin_name"] = admin[1]
            return redirect(url_for("dashboard"))
        flash("Wrong username or password", "danger")
    return render_template("login.html")


@app.route("/dashboard")
@login_required
def dashboard():
    total = marked_today = None
    try:
        total = count_students()
        marked_today = fetch_one(
            "SELECT COUNT(*) FROM attendance WHERE att_date = CURDATE()")[0]
    except Error:
        pass
    return render_template("dashboard.html", total=total,
                           max_students=MAX_STUDENTS, marked_today=marked_today)


@app.route("/logout")
def logout():
    session.clear()
    flash("Logged out successfully", "success")
    return redirect(url_for("login"))


# ---------------------------------------------------------------------
# Student helpers
# ---------------------------------------------------------------------

def get_rooms(include=None):
    """
    Rooms a student can be placed in: rooms with a free bed, plus the
    student's current room (so editing a student does not hide their room).
    Returns a list of (room_no, floor, capacity, free_beds).
    """
    _, rows = fetch_all(
        "SELECT room_no, floor, capacity, free_beds FROM v_room_occupancy "
        "WHERE free_beds > 0 OR room_no = %s ORDER BY room_no",
        (include or "",))
    return rows


def validate_student_form(form, rooms, new_student):
    """
    Validate every field using the same validators as the CLI.
    Returns (clean_values, errors). errors is a dict: field -> message.
    """
    clean, errors = {}, {}

    if new_student:
        ok, result = validate_student_id(form.get("student_id", ""))
        if not ok:
            errors["student_id"] = result
        elif student_exists(result):
            errors["student_id"] = f"Student ID {result} already exists."
        else:
            clean["student_id"] = result

    for col in FIELDS:
        ok, result = validate_field(col, form.get(col, ""))
        if ok:
            clean[col] = result
        else:
            errors[col] = result

    if "room_no" in clean and clean["room_no"] not in [r[0] for r in rooms]:
        errors["room_no"] = "Pick a room from the list (it must exist and have a free bed)."

    if ("date_of_birth" in clean and "admission_date" in clean
            and clean["admission_date"] <= clean["date_of_birth"]):
        errors["admission_date"] = "Admission date must be after date of birth."

    return clean, errors


# ---------------------------------------------------------------------
# Students: list + search
# ---------------------------------------------------------------------

@app.route("/students")
@login_required
def students():
    q = request.args.get("q", "").strip()
    sql = ("SELECT student_id, full_name, gender, "
           "TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age, "
           "phone, course, year_of_study, room_no FROM student ")
    params = ()
    if q:
        # Search by ID (exact) or part of the name.
        sql += "WHERE full_name LIKE %s OR CAST(student_id AS CHAR) = %s "
        params = (f"%{q}%", q)
    sql += "ORDER BY student_id"
    try:
        _, rows = fetch_all(sql, params)
        total = count_students()
    except Error as e:
        flash(friendly_error(e), "danger")
        rows, total = [], 0
    return render_template("students.html", rows=rows, q=q,
                           total=total, max_students=MAX_STUDENTS)


# ---------------------------------------------------------------------
# Students: add
# ---------------------------------------------------------------------

@app.route("/students/add", methods=["GET", "POST"])
@login_required
def add_student():
    try:
        if count_students() >= MAX_STUDENTS:
            flash(f"Registration blocked: the hostel already has "
                  f"{MAX_STUDENTS} students.", "danger")
            return redirect(url_for("students"))
        rooms = get_rooms()
    except Error as e:
        flash(friendly_error(e), "danger")
        return redirect(url_for("students"))

    if not rooms:
        flash("Registration blocked: every room is full.", "danger")
        return redirect(url_for("students"))

    if request.method == "POST":
        clean, errors = validate_student_form(request.form, rooms, new_student=True)
        if not errors:
            sql = ("INSERT INTO student (student_id, full_name, gender, "
                   "date_of_birth, phone, guardian_name, guardian_phone, "
                   "address, course, year_of_study, room_no, admission_date) "
                   "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)")
            try:
                execute(sql, (clean["student_id"],) + tuple(clean[c] for c in FIELDS))
                flash(f"Student {clean['student_id']} ({clean['full_name']}) "
                      f"added to room {clean['room_no']}.", "success")
                return redirect(url_for("students"))
            except Error as e:
                flash("Could not add student: " + friendly_error(e), "danger")
        return render_template("student_form.html", mode="add", rooms=rooms,
                               values=request.form, errors=errors)

    return render_template("student_form.html", mode="add", rooms=rooms,
                           values={}, errors={})


# ---------------------------------------------------------------------
# Students: edit
# ---------------------------------------------------------------------

@app.route("/students/<int:student_id>/edit", methods=["GET", "POST"])
@login_required
def edit_student(student_id):
    try:
        cols, rows = fetch_all("SELECT * FROM student WHERE student_id = %s",
                               (student_id,))
    except Error as e:
        flash(friendly_error(e), "danger")
        return redirect(url_for("students"))
    if not rows:
        flash(f"No student with ID {student_id}.", "danger")
        return redirect(url_for("students"))

    current = dict(zip(cols, rows[0]))
    rooms = get_rooms(include=current["room_no"])

    if request.method == "POST":
        clean, errors = validate_student_form(request.form, rooms, new_student=False)
        if not errors:
            sql = ("UPDATE student SET full_name=%s, gender=%s, date_of_birth=%s, "
                   "phone=%s, guardian_name=%s, guardian_phone=%s, address=%s, "
                   "course=%s, year_of_study=%s, room_no=%s, admission_date=%s "
                   "WHERE student_id=%s")
            try:
                execute(sql, tuple(clean[c] for c in FIELDS) + (student_id,))
                flash(f"Student {student_id} updated.", "success")
                return redirect(url_for("students"))
            except Error as e:
                flash("Could not update: " + friendly_error(e), "danger")
        return render_template("student_form.html", mode="edit", rooms=rooms,
                               values=request.form, errors=errors,
                               student_id=student_id)

    return render_template("student_form.html", mode="edit", rooms=rooms,
                           values=current, errors={}, student_id=student_id)


# ---------------------------------------------------------------------
# Students: delete (POST only, so a link click can never delete)
# ---------------------------------------------------------------------

@app.route("/students/<int:student_id>/delete", methods=["POST"])
@login_required
def delete_student(student_id):
    try:
        if not student_exists(student_id):
            flash(f"No student with ID {student_id}.", "danger")
        else:
            # Attendance rows are removed automatically (ON DELETE CASCADE).
            execute("DELETE FROM student WHERE student_id = %s", (student_id,))
            flash(f"Student {student_id} deleted.", "success")
    except Error as e:
        flash("Could not delete: " + friendly_error(e), "danger")
    return redirect(url_for("students"))


# ---------------------------------------------------------------------
# Attendance: mark / edit one day for all students
# ---------------------------------------------------------------------

@app.route("/attendance", methods=["GET", "POST"])
@login_required
def attendance():
    # The date comes from the URL (?att_date=...) or the form; default today.
    raw = request.values.get("att_date") or date.today().isoformat()
    date_ok, att_date = validate_date(raw, "Attendance date")
    if not date_ok:
        flash(att_date, "danger")          # att_date holds the error message
        att_date = date.today()

    try:
        _, student_rows = fetch_all(
            "SELECT student_id, full_name, room_no FROM student ORDER BY student_id")
        _, marked_rows = fetch_all(
            "SELECT student_id, status FROM attendance WHERE att_date = %s",
            (att_date,))
    except Error as e:
        flash(friendly_error(e), "danger")
        return redirect(url_for("dashboard"))

    existing = dict(marked_rows)           # student_id -> status already saved

    if request.method == "POST" and date_ok:
        if not student_rows:
            flash("There are no students to mark.", "danger")
        else:
            data, bad = [], []
            for sid, name, _room in student_rows:
                status = request.form.get(f"status_{sid}")
                if status not in STATUSES:
                    bad.append(name)
                else:
                    data.append((sid, att_date, status, session["admin_id"]))
            if bad:
                flash("Choose a status for: " + ", ".join(bad), "danger")
            else:
                # One transaction: every row saved, or none (see execute_many).
                # ON DUPLICATE KEY UPDATE changes an already-marked day instead
                # of failing on UNIQUE (student_id, att_date).
                sql = ("INSERT INTO attendance (student_id, att_date, status, marked_by) "
                       "VALUES (%s, %s, %s, %s) "
                       "ON DUPLICATE KEY UPDATE status = VALUES(status), "
                       "marked_by = VALUES(marked_by)")
                try:
                    execute_many(sql, data)
                    flash(f"Attendance for {att_date.strftime('%d %b %Y')} saved "
                          f"({len(data)} students).", "success")
                    return redirect(url_for("attendance",
                                            att_date=att_date.isoformat()))
                except Error as e:
                    flash("Could not save attendance: " + friendly_error(e), "danger")

    return render_template("attendance.html",
                           students=student_rows, existing=existing,
                           att_date=att_date.isoformat(),
                           today=date.today().isoformat(),
                           statuses=STATUSES)


# ---------------------------------------------------------------------
# Attendance report: percentage per student, defaulters highlighted
# ---------------------------------------------------------------------

@app.route("/attendance/report")
@login_required
def attendance_report():
    only_defaulters = request.args.get("filter") == "defaulters"
    sql = ("SELECT student_id, full_name, room_no, total_days, present_days, "
           "absent_days, leave_days, attendance_pct FROM v_attendance_summary ")
    if only_defaulters:
        sql += "WHERE attendance_pct < %s "
        params = (DEFAULTER_LIMIT,)
    else:
        params = ()
    sql += "ORDER BY student_id"
    try:
        _, rows = fetch_all(sql, params)
    except Error as e:
        flash(friendly_error(e), "danger")
        rows = []
    return render_template("attendance_report.html", rows=rows,
                           only_defaulters=only_defaulters,
                           limit=DEFAULTER_LIMIT)


if __name__ == "__main__":
    app.run(debug=True)