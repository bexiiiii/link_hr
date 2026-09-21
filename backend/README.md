# Link HR backend extensions

`link_hr/api/team_attendance.py` is the server endpoint used by the mobile HR
workspace. It exposes only active employees' daily first arrival, final departure
and current GPS point. The endpoint checks the Frappe roles `HR Manager`, `HR User`
or `System Manager` before any data is returned.

Production target: `/opt/link_app/link/link_hr/api/team_attendance.py` on the Link
server. Rebuild the `link_app` backend image after updating it.
