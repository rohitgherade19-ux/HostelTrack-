# Stage 6: Final Documentation

## 1. Objective
Complete the project deliverables: a project report outline, viva preparation,
and one combined README that lets anyone set up, run and test the system from scratch.

## 2. What we did
1. Wrote `docs/report_outline.md`: 11 chapters plus front matter, references and appendices. Each section says which project file to take the content from.
2. Wrote `docs/viva_questions.md`: 10 core viva questions with short answers, plus 10 quick follow-ups.
3. Wrote the combined root `README.md`:
   - features
   - design summary
   - folder structure
   - setup and run steps
   - testing
   - troubleshooting, including the real problems met during development
   - a documentation index
   - future scope
4. Checked every deliverable in the original requirement list (table below).

## 3. Files created or modified
| File | Purpose |
|------|---------|
| `README.md` | Final combined README (project root) |
| `docs/report_outline.md` | Project report chapter outline |
| `docs/viva_questions.md` | Viva questions and answers |
| `docs/README_STAGE6.md` | This file |

## 4. Technologies and tools used
| Technology | Version | Why used |
|-----------|---------|----------|
| Markdown | - | All documentation. Renders on GitHub |
| Mermaid | v10+ | ER diagram as text (`er_diagram.md`) |
| Git | any recent | Version history, one commit per stage |

## 5. Key concepts covered
The viva questions cover:
- normalization (3NF / BCNF)
- referential actions
- composite UNIQUE
- triggers vs CHECK
- derived attributes
- views
- SQL injection prevention
- transactions and ACID
- WHERE vs HAVING
- indexes and LIKE patterns

The follow-ups add:
- PK vs UNIQUE
- natural vs surrogate keys
- candidate keys
- join types
- correlated subqueries
- hashing
- SIGNAL
- function vs procedure
- DDL vs DML
- data type choice

### Deliverables checklist
| # | Required deliverable | Where |
|---|----------------------|-------|
| 1 | ER diagram, relational schema, normalization proof | `docs/er_diagram.md` |
| 2 | Complete SQL scripts and sample data | `sql/schema.sql`, `sql/seed.sql` |
| 3 | Complete runnable source code with comments | `src/*.py` |
| 4 | Sample queries with expected output | `sql/queries.sql` |
| 5 | Test cases and results | `tests/test_cases.md`, `tests/edge_cases.sql` |
| 6 | Setup and run instructions | `README.md` sections 4–5 |
| 7 | Project report outline | `docs/report_outline.md` |
| 8 | 10 viva questions with short answers | `docs/viva_questions.md` |
| 9 | README_STAGE0 to README_STAGE6 plus the final README.md | `docs/`, `README.md` |

## 6. How to run / test this stage
Final end-to-end check on a clean setup:
```powershell
# 1. Reload the database (MySQL Command Line Client)
#    SOURCE D:/hostel-management/sql/schema.sql;
#    SOURCE D:/hostel-management/sql/seed.sql;

# 2. Run the app
cd D:\hostel-management\src
python main.py          # warden / admin123 -> 2 -> 8 shows defaulters 108, 104, 112

# 3. Run the rule tests (Command Line Client)
#    SOURCE D:/hostel-management/tests/edge_cases.sql;
```
To check the documentation, push to GitHub and open `README.md`. The links and the
Mermaid ER diagram should render.

## 7. Output / results
- A complete project matching the folder structure in the requirement.
- All 9 deliverables present (checklist above).
- 83 documented test cases, ready for the Actual / Result columns to be filled.

## 8. Issues faced and fixes (whole project)
| Stage | Issue | Fix |
|-------|-------|-----|
| 1 | CASCADE on student → room would delete students | RESTRICT |
| 2 | CHECK cannot count rows | Triggers with SIGNAL |
| 3 | Column names cannot be `%s` | Whitelist |
| 4 | Half-saved day on error | One transaction per day |
| 4 | Password prompt looked frozen / IDE consoles | Hint text and a fallback to visible input |
| 4 | Username and password entered the wrong way round | Login details stated clearly in README |
| 4 | Stray `0` typed into `schema.sql` left an empty database | Restored the line and re-ran. Documented in troubleshooting |
| 5 | 100-limit test needs 88 rows | Stored procedure with a loop and test rooms |
| 5 | Destructive tests lose data | `START TRANSACTION ... ROLLBACK` |

## 9. Next stage
The project is complete. Suggested next steps:
- fill in `tests/test_cases.md` and take the screenshots listed in the report outline (Chapter 7.5 and 8.3)
- write the report from `docs/report_outline.md`
- optionally, push to GitHub
