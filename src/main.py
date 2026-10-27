"""
main.py
-------
Entry point. Run from the src folder:   python main.py

Flow: admin login (3 attempts) -> main menu -> module menus.
"""

import hashlib
import sys
from getpass import getpass
from mysql.connector import Error

from db import fetch_one, friendly_error
from student import student_menu
from attendance import attendance_menu

MAX_LOGIN_ATTEMPTS = 3
def read_password():
    """
    In a real terminal (Command Prompt, PowerShell, VS Code terminal) the
    password is hidden: nothing appears on screen while typing, not even *.
    In IDE run windows (PyCharm Run, IDLE, VS Code Output panel) getpass may
    not accept input, so we fall back to normal visible input there.
    """
    if sys.stdin.isatty():
        return getpass("Password (typing is hidden, just type and press Enter): ")
    return input("Password: ")


def login():
    """
    Ask for username and password. Returns the admin row
    (admin_id, full_name) on success, or None after 3 failed attempts.
    """
    print("========== HOSTEL MANAGEMENT SYSTEM ==========")
    print("                 Warden Login")
    for attempt in range(1, MAX_LOGIN_ATTEMPTS + 1):
        username = input("Username: ").strip()
        password = read_password()
        # Compare HASHES: the plain password is never stored or compared.
        admin = fetch_one(
            "SELECT admin_id, full_name FROM admin "
            "WHERE username = %s AND password_hash = %s",
            (username, hash_password(password)))
        if admin:
            print(f"\nWelcome, {admin[1]}!")
            return admin
        left = MAX_LOGIN_ATTEMPTS - attempt
        print(f"Wrong username or password. Attempts left: {left}\n")
    return None


def main_menu(admin):
    while True:
        print("\n============== MAIN MENU ==============")
        print("  1. Student Management")
        print("  2. Attendance")
        print("  0. Logout and exit")
        choice = input("Choice: ").strip()
        if choice == "1":
            student_menu()
        elif choice == "2":
            attendance_menu(admin[0])      # admin_id is saved as marked_by
        elif choice == "0":
            print("Logged out. Goodbye!")
            return
        else:
            print("Invalid choice, try again.")


def main():
    try:
        admin = login()
    except Error as e:
        print("Cannot reach the database:", friendly_error(e))
        print("Is MySQL running, and did you run schema.sql and seed.sql?")
        return
    if admin is None:
        print("Too many failed attempts. Exiting.")
        return
    try:
        main_menu(admin)
    except KeyboardInterrupt:              # Ctrl+C exits cleanly
        print("\nExiting.")


if __name__ == "__main__":
    main()