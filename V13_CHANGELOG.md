# Edvora V13

## Admissions / Students
- Admission numbers are generated automatically at the database level using a school-scoped `ADM-YYYY-####` format.
- The student form no longer asks the administrator to type an admission number.
- Student creation is routed through an authenticated server endpoint.

## Classes
- Class creation now uses an authenticated server endpoint.
- Only school owners/admins can create classes.
- Duplicate class names return a clear error.

## Calendar / Timetable
- Calendar is now the interactive weekly timetable view.
- Admins select a class from a dropdown and see that class's weekly schedule.
- Admins can add, edit, and remove timetable periods.
- Teacher selection is attached to timetable periods.
- Teachers see only periods for their assigned subjects/classes and cannot edit or remove timetable entries.
- Timetable rows can automatically create the matching teacher-subject-class assignment when an administrator assigns a teacher to a period.

## Typography
- Normalized dashboard page headings, body copy, controls, tables, labels, navigation, notices, and status text to remove the previous 7px-11px micro-text inconsistency.
