# -*- coding: utf-8 -*-
"""Permission-safe attendance feed for the Link native HR workspace."""

from calendar import monthrange
from collections import defaultdict
from datetime import date as date_type

import frappe
from frappe.utils import flt, getdate, now_datetime, today

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
				"last_event_time": last.time if last else None,
			}
		)

	return {"date": str(day), "updated_at": now_datetime(), "items": items}


@frappe.whitelist()
def monthly(month=None):
	"""Return an HR-only monthly attendance summary for every active employee."""
	_check_access()
	value = str(month or today())[:7]
	try:
		year, month_number = (int(part) for part in value.split("-"))
		start = date_type(year, month_number, 1)
	except (TypeError, ValueError):
		frappe.throw("Invalid month")
	end = date_type(year, month_number, monthrange(year, month_number)[1])
	employees = _employees()
	names = [employee.name for employee in employees]

	attendance = frappe.get_all(
		"Attendance",
		filters={
			"employee": ("in", names or [""]),
			"attendance_date": ("between", [start, end]),
			"docstatus": ("<", 2),
		},
		fields=[
			"employee",
			"attendance_date",
			"status",
			"working_hours",
			"late_entry",
		],
	)
	checkins = frappe.get_all(
		"Employee Checkin",
		filters={
			"employee": ("in", names or [""]),
			"time": ("between", [f"{start} 00:00:00", f"{end} 23:59:59"]),
		},
		fields=["employee", "log_type", "time"],
		order_by="time asc",
	)

	stats = defaultdict(
		lambda: {
			"present_days": 0.0,
			"absent_days": 0.0,
			"leave_days": 0.0,
			"late_days": 0,
			"working_hours": 0.0,
			"recorded_days": set(),
		}
	)
	for row in attendance:
		item = stats[row.employee]
		day = str(row.attendance_date)
		item["recorded_days"].add(day)
		if row.status in ("Present", "Work From Home"):
			item["present_days"] += 1
		elif row.status == "Half Day":
			item["present_days"] += 0.5
			item["absent_days"] += 0.5
		elif row.status == "On Leave":
			item["leave_days"] += 1
		elif row.status == "Absent":
			item["absent_days"] += 1
		item["late_days"] += 1 if row.late_entry else 0
		item["working_hours"] += flt(row.working_hours)

	by_employee_day = defaultdict(list)
	for row in checkins:
		by_employee_day[(row.employee, str(getdate(row.time)))].append(row)
	for (employee, day), rows in by_employee_day.items():
		item = stats[employee]
		if day in item["recorded_days"]:
			continue
		first_in = next((row.time for row in rows if row.log_type == "IN"), None)
		last_out = next(
			(row.time for row in reversed(rows) if row.log_type == "OUT"), None
		)
		if first_in:
			item["present_days"] += 1
			item["recorded_days"].add(day)
		if first_in and last_out and last_out > first_in:
			item["working_hours"] += (last_out - first_in).total_seconds() / 3600

	report_end = min(end, getdate(today())) if start <= getdate(today()) else start
	working_days = sum(
		1
		for day_number in range(1, report_end.day + 1)
		if date_type(year, month_number, day_number).weekday() < 5
	)
	items = []
	for employee in employees:
		item = stats[employee.name]
		covered = item["present_days"] + item["absent_days"] + item["leave_days"]
		items.append(
			{
				"employee": employee.name,
				"employee_name": employee.employee_name,
				"designation": employee.designation,
				"department": employee.department,
				"image": employee.image,
				"working_days": working_days,
				"present_days": item["present_days"],
				"absent_days": item["absent_days"],
				"leave_days": item["leave_days"],
				"missing_days": max(0, working_days - covered),
				"late_days": item["late_days"],
				"working_hours": round(item["working_hours"], 2),
			}
		)

	return {
		"month": value,
		"working_days": working_days,
		"updated_at": now_datetime(),
		"items": items,
	}
