import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

enum SessionPhase { signedOut, loading, ready, noEmployee }

class Session extends ChangeNotifier {
  Session._();

  static final Session instance = Session._();

  static const _profileKey = 'link.profile';
  static const _lockKey = 'link.biometricLock';
  static const _emailKey = 'link.lastEmail';

  static const premiumFeatures = {'analysis', 'payroll_calc', 'checklists', 'tasks', 'notices', 'achievements', 'points'};

  final _api = Api.instance;

  SessionPhase phase = SessionPhase.signedOut;
  Json? user;
  Json? employee;
  Json hr = {};
  String currency = 'KZT';
  bool biometricLock = false;
  bool unlocked = false;
  String lastEmail = '';

  /// Subscription of the company (link.saas.get_plan). Null on servers without plans: everything is allowed.
  Json? plan;

  bool hasFeature(String feature) {
    final features = plan?['features'];
    if (features is! List) return true;
    return features.contains(feature);
  }

  bool get isPremium => plan == null || plan!['tier'] == 'premium';
  int? get planDaysLeft => plan?['days_left'] is num ? (plan!['days_left'] as num).toInt() : null;
  bool get planExpired => plan?['expired'] == true;

  /// Bumped whenever a screen mutates data other screens display.
  final dataVersion = ValueNotifier<int>(0);

  void notifyDataChanged() => dataVersion.value++;

  String get userId => user?['name']?.toString() ?? '';
  String get employeeId => employee?['name']?.toString() ?? '';
  String get company => employee?['company']?.toString() ?? '';
  String get fullName => (employee?['employee_name'] ?? user?['full_name'] ?? '').toString();
  String get firstName {
    final first = (employee?['first_name'] ?? user?['first_name'] ?? '').toString();
    return first.isNotEmpty ? first : fullName.split(' ').first;
  }

  String? get image => (employee?['image'] ?? user?['user_image'])?.toString();
  String get designation => employee?['designation']?.toString() ?? '';
  String get department => employee?['department']?.toString() ?? '';
  bool get isManager => roles.any((r) => const {'HR Manager', 'HR User', 'System Manager'}.contains(r));
  List<String> get roles => (user?['roles'] as List? ?? const []).map((e) => e.toString()).toList();
  bool get checkinAllowed => hr['allow_employee_checkin_from_mobile_app'] != 0;
  bool get geolocationTracking => hr['allow_geolocation_tracking'] == 1 || hr['allow_geolocation_tracking'] == true;
  bool get preventSelfLeaveApproval =>
      hr['prevent_self_leave_approval'] == 1 || hr['prevent_self_leave_approval'] == true;

  Future<void> restore() async {
    _api.onSessionExpired = _expire;
    await _api.restore();
    final prefs = await SharedPreferences.getInstance();
    biometricLock = prefs.getBool(_lockKey) ?? false;
    lastEmail = prefs.getString(_emailKey) ?? '';
    if (!_api.hasSession) return;
    final cached = prefs.getString(_profileKey);
    if (cached != null) {
      try {
        final j = jsonDecode(cached) as Map<String, dynamic>;
        user = (j['user'] as Map?)?.cast<String, dynamic>();
        employee = (j['employee'] as Map?)?.cast<String, dynamic>();
        hr = (j['hr'] as Map?)?.cast<String, dynamic>() ?? {};
        currency = j['currency']?.toString() ?? 'KZT';
        plan = (j['plan'] as Map?)?.cast<String, dynamic>();
      } catch (_) {}
    }
    phase = employee != null ? SessionPhase.ready : SessionPhase.loading;
  }

  Future<void> login(String email, String password) async {
    await _api.login(email, password);
    lastEmail = email;
    unlocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
    phase = SessionPhase.loading;
    notifyListeners();
    await refresh();
  }

  /// Loads the same boot data the PWA fetches: user, employee, HR settings.
  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _api.call('hrms.api.get_current_user_info'),
        _api.call('hrms.api.get_current_employee_info'),
        _api.call('hrms.api.get_hr_settings').catchError((_) => <String, dynamic>{}),
        _api.call('link.saas.get_plan').catchError((_) => null),
      ]);
      plan = (results[3] as Map?)?.cast<String, dynamic>();
      user = (results[0] as Map?)?.cast<String, dynamic>();
      employee = (results[1] as Map?)?.cast<String, dynamic>();
      hr = (results[2] as Map?)?.cast<String, dynamic>() ?? {};
      if (employee != null) {
        final extra = await Future.wait([
          _api.list('Employee', fields: ['name', 'image'], filters: {'name': employeeId}, limit: 1),
          _api.call('frappe.client.get_value', {
            'doctype': 'Company',
            'filters': company,
            'fieldname': 'default_currency',
          }).catchError((_) => null),
        ]);
        final rows = extra[0] as List<Json>;
        if (rows.isNotEmpty) employee!['image'] = rows.first['image'];
        final cur = extra[1];
        if (cur is Map && cur['default_currency'] != null) currency = cur['default_currency'].toString();
      }
      phase = employee == null ? SessionPhase.noEmployee : SessionPhase.ready;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _profileKey, jsonEncode({'user': user, 'employee': employee, 'hr': hr, 'currency': currency, 'plan': plan}));
      notifyListeners();
    } on ApiException {
      if (!_api.hasSession) return;
      if (employee == null) {
        phase = SessionPhase.signedOut;
        await _api.clear();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _wipe();
  }

  Future<void> setBiometricLock(bool value) async {
    biometricLock = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockKey, value);
    notifyListeners();
  }

  void markUnlocked() {
    unlocked = true;
    notifyListeners();
  }

  void _expire() {
    if (phase == SessionPhase.signedOut) return;
    _api.clear();
    _wipe();
  }

  Future<void> _wipe() async {
    user = null;
    employee = null;
    hr = {};
    plan = null;
    unlocked = false;
    phase = SessionPhase.signedOut;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    notifyListeners();
  }
}
