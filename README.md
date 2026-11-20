# Student Records – Oracle SQL / PL/SQL

A small learning project that models student registration data in Oracle, using the kind of patterns found in university student information systems: relational tables, PL/SQL packages, business rules, audit triggers and reporting extracts.

> This is a personal learning project. It is **not** Ellucian Banner and does not use Banner tables or code.

## What it does

- Stores students, courses and course registrations
- Enforces business rules in PL/SQL: no duplicate registrations, a maximum of 18 credits per term, no registration while a student has a hold, and validation of student and course
- Logs every registration insert and delete in an audit table through a trigger
- Produces a CSV-style student credit-load report
- Includes queries such as students with no registrations in a term (LEFT JOIN)

## Database objects

| Object | Type | Purpose |
|---|---|---|
| `students`, `courses`, `registrations` | Tables | Core data with primary keys, foreign keys and a unique constraint |
| `reg_audit` | Table | Audit log of registration changes |
| `v_student_load` | View | Total credits per student per term |
| `get_total_credits` | Function | Credits for one student in one term |
| `trg_reg_audit` | Trigger | Writes INSERT and DELETE events to `reg_audit` |
| `reg_pkg` | Package | `register_student`, `drop_course`, `get_total_credits`, `student_load_report` |

## Error handling

| Code | Meaning |
|---|---|
| -20001 | Student already registered |
| -20002 | Credit limit of 18 exceeded |
| -20003 | Course not found |
| -20004 | No such registration to drop |
| -20005 | Student has a registration hold |
| -20006 | Student not found |

## How to run

1. Open Oracle Live SQL, Oracle FreeSQL or any Oracle database (tested on Oracle FreeSQL)
2. Run `student_db.sql` in a fresh schema using **Run Script**
3. Try the package:

```sql
SET SERVEROUTPUT ON

BEGIN
  reg_pkg.register_student(1001, 'MAT110', '202610');
  reg_pkg.student_load_report('202610');
END;
/
```

## Skills demonstrated

Oracle SQL (joins, views, constraints, aggregates), PL/SQL (packages, procedures, functions, cursors, triggers, exception handling), data integrity rules, and audit logging.

## Roadmap

- [ ] ASP.NET Core Web API (C#) to read and write registrations through REST endpoints
- [ ] Connect to Oracle using ODP.NET
- [ ] Scheduled job to produce the load report daily
- [ ] Unit tests for the package rules

## Author

Manav Amolik – Dubai, UAE
