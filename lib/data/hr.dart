import '../core/api.dart';
import '../core/fmt.dart';
import '../core/session.dart';

/// Every HRMS call the Frappe HR PWA makes, mirrored for the native app.
abstract final class Hr {
  static Api get _api => Api.instance;
  static Session get _s => Session.instance;

  static List<Json> _rows(dynamic v) => (v as List? ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

  // Attendance ------------------------------------------------------------

  static Future<List<Json>> checkins({int limit = 20, int start = 0}) => _api.list(
        'Employee Checkin',
        fields: ['name', 'log_type', 'time', 'latitude', 'longitude', 'device_id', 'shift'],
        filters: {'employee': _s.employeeId},
        orderBy: 'time desc',
        limit: limit,
        start: start,
      );

  static Future<List<Json>> checkinsBetween(DateTime from, DateTime to) => _api.list(
        'Employee Checkin',
        fields: ['name', 'log_type', 'time'],
        filters: [
          ['employee', '=', _s.employeeId],
          ['time', 'between', [Fmt.iso(from), Fmt.iso(to)]],
        ],
        orderBy: 'time asc',
        limit: 2000,
      );

  static Future<Json> checkin(String logType, {double? latitude, double? longitude}) => _api.insert({
        'doctype': 'Employee Checkin',
        'employee': _s.employeeId,
        'log_type': logType,
        'time': Fmt.isoDateTime(DateTime.now()),
        'latitude': ?latitude,
        'longitude': ?longitude,
        'device_id': 'Link iOS',
      });

  /// Active shift location (office geofence) for the employee today, or null
  /// when HR has not assigned one.
  static Future<ShiftLocation?> shiftLocation() async {
    final today = Fmt.iso(DateTime.now());
    final rows = await _api.list('Shift Assignment',
        fields: ['shift_location', 'shift_type', 'end_date'],
        filters: [
          ['employee', '=', _s.employeeId],
          ['docstatus', '=', 1],
          ['status', '=', 'Active'],
          ['start_date', '<=', today],
          ['shift_location', 'is', 'set'],
        ],
        orderBy: 'start_date desc',
        limit: 20);
    final active = rows.where((r) {
      final end = Fmt.parse(r['end_date']);
      return end == null || !Fmt.dateOnly(end).isBefore(Fmt.dateOnly(DateTime.now()));
    }).toList();
    if (active.isEmpty) return null;
    final loc = await _api.list('Shift Location',
        fields: ['name', 'location_name', 'checkin_radius', 'latitude', 'longitude'],
        filters: {'name': active.first['shift_location']},
        limit: 1);
    if (loc.isEmpty) return null;
    final l = loc.first;
    return ShiftLocation(
      name: (l['location_name'] ?? l['name']).toString(),
      radius: Fmt.number(l['checkin_radius']).toDouble(),
      latitude: Fmt.number(l['latitude']).toDouble(),
      longitude: Fmt.number(l['longitude']).toDouble(),
    );
  }

  static Future<String> attachCheckinPhoto(String checkin, List<int> bytes, String fileName) async {
    final name = fileName.contains('.') ? fileName : '$fileName.jpg';
    final file = await _api.uploadFile(
      bytes: bytes,
      fileName: 'checkin-${DateTime.now().millisecondsSinceEpoch}-$name',
      doctype: 'Employee Checkin',
      docname: checkin,
    );
    final url = file['file_url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Сервер не сохранил фото. Попробуйте ещё раз.');
    return url;
  }

  /// Photos attached to check-ins, keyed by check-in name (latest photo wins).
  static Future<Map<String, String>> checkinPhotos(List<String> names) async {
    if (names.isEmpty) return {};
    final rows = await _api.list('File',
        fields: ['file_url', 'attached_to_name'],
        filters: [
          ['attached_to_doctype', '=', 'Employee Checkin'],
          ['attached_to_name', 'in', names],
        ],
        orderBy: 'creation asc',
        limit: 1000);
    return {for (final r in rows) r['attached_to_name'].toString(): r['file_url'].toString()};
  }

  static Future<List<Json>> todayArrivals() {
    final now = DateTime.now();
    return _api.list('Employee Checkin',
        fields: ['name', 'log_type', 'time'],
        filters: [
          ['employee', '=', _s.employeeId],
          ['log_type', '=', 'IN'],
          ['time', 'between', [Fmt.iso(now), Fmt.iso(DateTime(now.year, now.month, now.day + 1))]],
        ],
        orderBy: 'time desc',
        limit: 20);
  }

  static Future<Map<String, String>> calendarEvents(DateTime from, DateTime to) async {
    final data = await _api.call('hrms.api.get_attendance_calendar_events', {
      'from_date': Fmt.iso(from),
      'to_date': Fmt.iso(to),
    });
    return (data as Map? ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static Future<List<Json>> holidays() async =>
      _rows(await _api.call('hrms.api.get_holidays_for_employee', {'employee': _s.employeeId}));

  static Future<List<Json>> shiftAssignments() async => _rows(await _api.call('hrms.api.get_shifts'));

  static Future<List<Json>> shiftTypes() =>
      _api.list('Shift Type', fields: ['name', 'start_time', 'end_time'], orderBy: 'name asc', limit: 200);

  static Future<List<Json>> shiftApprovers() async =>
      _rows(await _api.call('hrms.api.get_shift_request_approvers', {'employee': _s.employeeId}));

  // Requests --------------------------------------------------------------

  static Map<String, dynamic> _requestArgs(bool team, int? limit, {bool withApprover = true}) => {
        'employee': _s.employeeId,
        if (team && withApprover) 'approver_id': _s.userId,
        'for_approval': team ? 1 : 0,
        'limit': ?limit,
      };

  static Future<List<Json>> leaves({bool team = false, int? limit}) async =>
      _rows(await _api.call('hrms.api.get_leave_applications', _requestArgs(team, limit)));

  static Future<List<Json>> expenseClaims({bool team = false, int? limit}) async =>
      _rows(await _api.call('hrms.api.get_expense_claims', _requestArgs(team, limit)));

  static Future<List<Json>> shiftRequests({bool team = false, int? limit}) async =>
      _rows(await _api.call('hrms.api.get_shift_requests', _requestArgs(team, limit)));

  static Future<List<Json>> attendanceRequests({bool team = false, int? limit}) async => _rows(
      await _api.call('hrms.api.get_attendance_requests', _requestArgs(team, limit, withApprover: false)));

  static Future<List<Json>> advances({int? limit}) => _api.list(
        'Employee Advance',
        fields: [
          'name',
          'employee',
          'employee_name',
          'purpose',
          'advance_amount',
          'paid_amount',
          'claimed_amount',
          'return_amount',
          'status',
          'posting_date',
          'currency',
          'docstatus',
          'creation',
        ],
        filters: {
          'employee': _s.employeeId,
          'docstatus': ['!=', 2],
        },
        orderBy: 'posting_date desc',
        limit: limit ?? 500,
      );

  static Future<List<Json>> advanceBalance() async => _rows(await _api.call('hrms.api.get_employee_advance_balance'));

  // Leaves ----------------------------------------------------------------

  static Future<Map<String, Json>> leaveBalance() async {
    final data = await _api.call('hrms.api.get_leave_balance_map');
    return (data as Map? ?? const {}).map((k, v) => MapEntry(k.toString(), (v as Map).cast<String, dynamic>()));
  }

  static Future<List<String>> leaveTypes(DateTime date) async {
    final data = await _api.call('hrms.api.get_leave_types', {'employee': _s.employeeId, 'date': Fmt.iso(date)});
    return (data as List? ?? const []).map((e) => e.toString()).toSet().toList();
  }

  static Future<num> leaveDays({
    required String leaveType,
    required DateTime from,
    required DateTime to,
    bool halfDay = false,
    DateTime? halfDayDate,
  }) async {
    final data = await _api.call('hrms.hr.doctype.leave_application.leave_application.get_number_of_leave_days', {
      'employee': _s.employeeId,
      'leave_type': leaveType,
      'from_date': Fmt.iso(from),
      'to_date': Fmt.iso(to),
      'half_day': halfDay ? 1 : 0,
      'half_day_date': halfDayDate == null ? null : Fmt.iso(halfDayDate),
    });
    return Fmt.number(data);
  }

  static Future<num> leaveBalanceOn({required String leaveType, required DateTime from, required DateTime to}) async {
    final data = await _api.call('hrms.hr.doctype.leave_application.leave_application.get_leave_balance_on', {
      'employee': _s.employeeId,
      'leave_type': leaveType,
      'date': Fmt.iso(from),
      'to_date': Fmt.iso(to),
      'consider_all_leaves_in_the_allocation_period': 1,
    });
    return Fmt.number(data);
  }

  static Future<Json> leaveApprovalDetails() async =>
      ((await _api.call('hrms.api.get_leave_approval_details', {'employee': _s.employeeId})) as Map? ?? {})
          .cast<String, dynamic>();

  // Expenses --------------------------------------------------------------

  static Future<Json> expenseSummary() async =>
      ((await _api.call('hrms.api.get_expense_claim_summary')) as Map? ?? {}).cast<String, dynamic>();

  static Future<List<Json>> expenseTypes() async => _rows(await _api.call('hrms.api.get_expense_claim_types'));

  static Future<Json> expenseApprovalDetails() async =>
      ((await _api.call('hrms.api.get_expense_approval_details', {'employee': _s.employeeId})) as Map? ?? {})
          .cast<String, dynamic>();

  static Future<Json> companyCostCenter() async => ((await _api.call(
              'hrms.api.get_company_cost_center_and_expense_account', {'company': _s.company})) as Map? ??
          {})
      .cast<String, dynamic>();

  static Future<List<Json>> unclaimedAdvances() async => _rows(await _api.call(
      'hrms.hr.doctype.expense_claim.expense_claim.get_advances', {'employee': _s.employeeId}));

  static Future<String?> advanceAccount() async =>
      (await _api.call('hrms.api.get_advance_account', {'company': _s.company}))?.toString();

  static Future<List<Json>> modesOfPayment() =>
      _api.list('Mode of Payment', fields: ['name', 'type'], filters: {'enabled': 1}, limit: 100);

  // Salary ----------------------------------------------------------------

  static Future<List<Json>> payrollPeriods() => _api.list(
        'Payroll Period',
        fields: ['name', 'start_date', 'end_date'],
        filters: {'company': _s.company},
        orderBy: 'start_date desc',
        limit: 50,
      );

  static Future<List<Json>> salarySlips({DateTime? from, DateTime? to}) => _api.list(
        'Salary Slip',
        fields: [
          'name',
          'start_date',
          'end_date',
          'posting_date',
          'currency',
          'gross_pay',
          'net_pay',
          'total_deduction',
          'year_to_date',
          'status',
        ],
        filters: [
          ['employee', '=', _s.employeeId],
          ['docstatus', '=', 1],
          if (from != null && to != null) ['start_date', 'between', [Fmt.iso(from), Fmt.iso(to)]],
        ],
        orderBy: 'end_date desc',
        limit: 500,
      );

  static Future<String> salarySlipPdf(String name) async =>
      (await _api.call('hrms.api.download_salary_slip', {'name': name})).toString();

  // Notifications ---------------------------------------------------------

  static Future<int> unreadNotifications() async =>
      Fmt.number(await _api.call('hrms.api.get_unread_notifications_count')).toInt();

  static Future<List<Json>> notifications({int start = 0, int limit = 20}) => _api.list(
        'PWA Notification',
        fields: ['name', 'from_user', 'message', 'read', 'creation', 'reference_document_type', 'reference_document_name'],
        filters: {'to_user': _s.userId},
        orderBy: 'creation desc',
        start: start,
        limit: limit,
      );

  static Future<void> markNotificationRead(String name) =>
      _api.setValue('PWA Notification', name, {'read': 1});

  static Future<void> markAllNotificationsRead() => _api.call('hrms.api.mark_all_notifications_as_read');

  // Workflow & permissions ------------------------------------------------

  static Future<Json> workflow(String doctype) async =>
      ((await _api.call('hrms.api.get_workflow', {'doctype': doctype})) as Map? ?? {}).cast<String, dynamic>();

  static Future<List<String>> workflowTransitions(Json doc) async {
    final data = await _api.call('frappe.model.workflow.get_transitions', {'doc': doc});
    final isOwner = doc['owner'] == _s.userId;
    return _rows(data)
        .where((t) => t['allow_self_approval'] == 1 || t['allow_self_approval'] == true || !isOwner)
        .map((t) => t['action'].toString())
        .toSet()
        .toList();
  }

  static Future<void> applyWorkflow(Json doc, String action) =>
      _api.call('frappe.model.workflow.apply_workflow', {'doc': doc, 'action': action});

  static Future<Map<String, bool>> docPermissions(String doctype, String name) async {
    final data = await _api.call('frappe.client.get_doc_permissions', {'doctype': doctype, 'docname': name});
    final perms = ((data as Map?)?['permissions'] as Map?) ?? const {};
    return perms.map((k, v) => MapEntry(k.toString(), v == 1 || v == true));
  }

  static Future<List<String>> writableFields(String doctype) async {
    final data = await _api.call('hrms.api.get_permitted_fields_for_write', {'doctype': doctype});
    return (data as List? ?? const []).map((e) => e.toString()).toList();
  }

  // People ----------------------------------------------------------------

  static List<Json>? _employeesCache;

  static Future<List<Json>> employees({bool refresh = false}) async {
    if (_employeesCache != null && !refresh) return _employeesCache!;
    _employeesCache = _rows(await _api.call('hrms.api.get_all_employees'));
    return _employeesCache!;
  }

  static Future<Json> employeeDoc() => _api.doc('Employee', _s.employeeId);

  static Future<String> reportsToName(String employee) async =>
      (await _api.call('hrms.api.get_reports_to_employee_name', {'employee': employee}))?.toString() ?? '';

  static Future<void> changePassword(String oldPassword, String newPassword) =>
      _api.call('frappe.core.doctype.user.user.update_password', {
        'old_password': oldPassword,
        'new_password': newPassword,
        'logout_all_sessions': 0,
      });

  static Future<void> resetPassword(String email) => _api.requestPasswordReset(email);

  // Kazakhstan HR documents (link app) -------------------------------------

  static Future<List<Json>> laborContracts() => _api.list(
        'KZ Labor Contract',
        fields: ['name', 'title', 'contract_number', 'contract_date', 'status', 'designation', 'wage_amount', 'docstatus'],
        filters: {'employee': _s.employeeId},
        orderBy: 'contract_date desc',
        limit: 100,
      );

  static Future<List<Json>> personnelOrders() => _api.list(
        'KZ Personnel Order',
        fields: ['name', 'title', 'order_type', 'order_number', 'order_date', 'status', 'effective_date', 'docstatus'],
        filters: {'employee': _s.employeeId},
        orderBy: 'order_date desc',
        limit: 100,
      );

  static Future<List<Json>> timesheets() => _api.list(
        'KZ Timesheet',
        fields: ['name', 'title', 'year', 'month', 'status', 'department', 'total_hours', 'docstatus'],
        filters: [
          ['KZ Timesheet Detail', 'employee', '=', _s.employeeId],
        ],
        orderBy: 'year desc, month desc',
        limit: 100,
      );
}

class ShiftLocation {
  const ShiftLocation({required this.name, required this.radius, required this.latitude, required this.longitude});

  final String name;
  final double radius;
  final double latitude;
  final double longitude;

  bool get hasPoint => latitude != 0 || longitude != 0;
}
