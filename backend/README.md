# Link HR backend extensions

`link_hr/api/team_attendance.py` is the server endpoint used by the mobile HR
workspace. It exposes active employees' daily first arrival, final departure,
current GPS point, and a real monthly summary assembled from Attendance and
Employee Checkin records. Both endpoints check the Frappe roles `HR Manager`,
`HR User` or `System Manager` before any data is returned.

- `get(date)` powers the live and daily views.
- `monthly(month)` powers the monthly HR report, including present, absent,
  leave, missing, late days and recorded working hours.

Production target: `/opt/link_app/link/link_hr/api/team_attendance.py` on the Link
server. Rebuild the `link_app` backend image after updating it.
