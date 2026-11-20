-- ============================================================
-- Student Records Mini Database (Oracle SQL / PL/SQL)
-- Author: Manav Amolik
-- Purpose: Learning project - student, course and registration
--          data with PL/SQL packages, triggers, views and reports
-- ============================================================


-- ============================================================
-- Tables: students, courses, registrations
-- ============================================================
CREATE TABLE students (
  student_id NUMBER PRIMARY KEY,
  first_name VARCHAR2(50),
  last_name  VARCHAR2(50),
  email      VARCHAR2(100),
  admit_term VARCHAR2(6)
);

CREATE TABLE courses (
  course_code VARCHAR2(10) PRIMARY KEY,
  title       VARCHAR2(100),
  credits     NUMBER(2)
);

CREATE TABLE registrations (
  reg_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id  NUMBER REFERENCES students(student_id),
  course_code VARCHAR2(10) REFERENCES courses(course_code),
  term_code   VARCHAR2(6),
  reg_date    DATE DEFAULT SYSDATE,
  CONSTRAINT uq_reg UNIQUE (student_id, course_code, term_code)
);


-- ============================================================
-- Sample data
-- ============================================================
INSERT INTO students VALUES (1001, 'Aisha', 'Khan', 'aisha@example.com', '202610');
INSERT INTO students VALUES (1002, 'Omar', 'Ali', 'omar@example.com', '202610');
INSERT INTO courses VALUES ('CSC101', 'Intro to Programming', 3);
INSERT INTO courses VALUES ('MAT110', 'Calculus I', 4);
COMMIT;


-- ============================================================
-- View: total credits per student per term
-- ============================================================
CREATE OR REPLACE VIEW v_student_load AS
SELECT r.student_id, r.term_code, SUM(c.credits) AS total_credits
FROM   registrations r
JOIN   courses c ON c.course_code = r.course_code
GROUP  BY r.student_id, r.term_code;


-- ============================================================
-- Function: total credits for a student in a term
-- ============================================================
CREATE OR REPLACE FUNCTION get_total_credits (
  p_student_id IN NUMBER,
  p_term       IN VARCHAR2
) RETURN NUMBER AS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(c.credits), 0) INTO v_total
  FROM   registrations r
  JOIN   courses c ON c.course_code = r.course_code
  WHERE  r.student_id = p_student_id AND r.term_code = p_term;
  RETURN v_total;
END;
/


-- ============================================================
-- Audit table and trigger: log every registration insert/delete
-- ============================================================
CREATE TABLE reg_audit (
  audit_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id  NUMBER,
  course_code VARCHAR2(10),
  action      VARCHAR2(10),
  action_date TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE OR REPLACE TRIGGER trg_reg_audit
AFTER INSERT OR DELETE ON registrations
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    INSERT INTO reg_audit (student_id, course_code, action)
    VALUES (:NEW.student_id, :NEW.course_code, 'INSERT');
  ELSE
    INSERT INTO reg_audit (student_id, course_code, action)
    VALUES (:OLD.student_id, :OLD.course_code, 'DELETE');
  END IF;
END;
/


-- ============================================================
-- Registration hold flag on students
-- ============================================================
ALTER TABLE students ADD hold_flag CHAR(1) DEFAULT 'N';


-- ============================================================
-- Package specification: registration logic
-- ============================================================
CREATE OR REPLACE PACKAGE reg_pkg AS
  PROCEDURE register_student (p_student_id IN NUMBER, p_course_code IN VARCHAR2, p_term IN VARCHAR2);
  PROCEDURE drop_course      (p_student_id IN NUMBER, p_course_code IN VARCHAR2, p_term IN VARCHAR2);
  FUNCTION  get_total_credits(p_student_id IN NUMBER, p_term IN VARCHAR2) RETURN NUMBER;
  PROCEDURE student_load_report (p_term IN VARCHAR2);
END reg_pkg;
/


-- ============================================================
-- Package body: registration logic
-- Rules: no registration if student has a hold, course must
-- exist, no duplicates, maximum 18 credits per term
-- ============================================================
CREATE OR REPLACE PACKAGE BODY reg_pkg AS

  FUNCTION get_total_credits (p_student_id IN NUMBER, p_term IN VARCHAR2) RETURN NUMBER AS
    v_total NUMBER;
  BEGIN
    SELECT NVL(SUM(c.credits), 0) INTO v_total
    FROM   registrations r JOIN courses c ON c.course_code = r.course_code
    WHERE  r.student_id = p_student_id AND r.term_code = p_term;
    RETURN v_total;
  END;

  PROCEDURE register_student (p_student_id IN NUMBER, p_course_code IN VARCHAR2, p_term IN VARCHAR2) AS
    v_new_credits NUMBER;
    v_hold        CHAR(1);
  BEGIN
    BEGIN
      SELECT hold_flag INTO v_hold FROM students WHERE student_id = p_student_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20006, 'Student not found');
    END;

    IF v_hold = 'Y' THEN
      RAISE_APPLICATION_ERROR(-20005, 'Student has a registration hold');
    END IF;

    BEGIN
      SELECT credits INTO v_new_credits FROM courses WHERE course_code = p_course_code;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'Course not found');
    END;

    IF get_total_credits(p_student_id, p_term) + v_new_credits > 18 THEN
      RAISE_APPLICATION_ERROR(-20002, 'Credit limit of 18 exceeded');
    END IF;

    INSERT INTO registrations (student_id, course_code, term_code)
    VALUES (p_student_id, p_course_code, p_term);
    COMMIT;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      RAISE_APPLICATION_ERROR(-20001, 'Student already registered');
  END;

  PROCEDURE drop_course (p_student_id IN NUMBER, p_course_code IN VARCHAR2, p_term IN VARCHAR2) AS
  BEGIN
    DELETE FROM registrations
    WHERE  student_id = p_student_id AND course_code = p_course_code AND term_code = p_term;
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20004, 'No such registration');
    END IF;
    COMMIT;
  END;

  PROCEDURE student_load_report (p_term IN VARCHAR2) AS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('STUDENT_ID,LAST_NAME,TOTAL_CREDITS');
    FOR rec IN (
      SELECT s.student_id, s.last_name, NVL(SUM(c.credits), 0) AS total
      FROM   students s
      LEFT JOIN registrations r ON r.student_id = s.student_id AND r.term_code = p_term
      LEFT JOIN courses c ON c.course_code = r.course_code
      GROUP  BY s.student_id, s.last_name
      ORDER  BY s.last_name
    ) LOOP
      DBMS_OUTPUT.PUT_LINE(rec.student_id || ',' || rec.last_name || ',' || rec.total);
    END LOOP;
  END;

END reg_pkg;
/


-- ============================================================
-- Queries
-- ============================================================

-- Registrations for a term, joined with student and course details
SELECT s.student_id, s.last_name, c.course_code, c.credits
FROM   registrations r
JOIN   students s ON s.student_id = r.student_id
JOIN   courses  c ON c.course_code = r.course_code
WHERE  r.term_code = '202610'
ORDER  BY s.last_name;

-- Students with no registrations in a term (LEFT JOIN)
-- Note: the term filter is in the ON clause so the outer join is kept
SELECT s.student_id, s.first_name, s.last_name
FROM   students s
LEFT JOIN registrations r
       ON r.student_id = s.student_id
      AND r.term_code = '202610'
WHERE  r.reg_id IS NULL;


-- ============================================================
-- Example usage (run separately)
-- ============================================================
-- SET SERVEROUTPUT ON
-- BEGIN
--   reg_pkg.register_student(1001, 'MAT110', '202610');
--   reg_pkg.student_load_report('202610');
-- END;
-- /
