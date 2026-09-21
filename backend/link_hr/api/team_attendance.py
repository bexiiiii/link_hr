# -*- coding: utf-8 -*-
"""Permission-safe attendance feed for the Link native HR workspace."""

from collections import defaultdict

import frappe
from frappe.utils import getdate, today

from .health import _check_access, _employees


@frappe.whitelist()
def get(date=None):
	"""Return each active employee's daily arrival/departure state for HR only."""
	_check_access()
	day = getdate(date or today())
	employees = _employees()
	names = [employee.name for employee in employees]
	logs = frappe.get_all(
		"Employee Checkin",
		filters={
			"employee": ("in", names or [""]),
			"time": ("between", [f"{day} 00:00:00", f"{day} 23:59:59"]),
		},
		fields=["employee", "log_type", "time", "latitude", "longitude"],
		order_by="time asc",
	)
	by_employee = defaultdict(list)
	for log in logs:
		by_employee[log.employee].append(log)

	items = []
	for employee in employees:
		rows = by_employee.get(employee.name, [])
		first_in = next((row.time for row in rows if row.log_type == "IN"), None)
		last_out = next(
			(row.time for row in reversed(rows) if row.log_type == "OUT"), None
		)
		last = rows[-1] if rows else None
		is_present = bool(last and last.log_type == "IN")
		items.append(
			{
				"employee": employee.name,
				"employee_name": employee.employee_name,
				"designation": employee.designation,
				"department": employee.department,
				"image": employee.image,
				"first_in": first_in,
				"last_out": last_out,
				"status": "present" if is_present else "left" if last else "absent",
				"latitude": last.latitude if is_present else None,
				"longitude": last.longitude if is_present else None,
			}
		)

	return {"date": str(day), "items": items}
