import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:link_mobile/models/task_model.dart';

class ApiService {
  static const String baseUrl = 'http://186.240.157.112:8000';
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;
  ApiService._internal();

  String? _cookieHeader;
  Map<String, dynamic>? _currentEmployee;
  List<TaskItem>? _cachedTasks;

  String? get cookieHeader => _cookieHeader;
  Map<String, dynamic>? get currentEmployee => _currentEmployee;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cookieHeader = prefs.getString('saved_cookies');
    final empJson = prefs.getString('saved_employee');
    if (empJson != null) {
      try {
        _currentEmployee = jsonDecode(empJson);
      } catch (_) {}
    }
  }

  bool get isLoggedIn => _cookieHeader != null && _cookieHeader!.isNotEmpty;

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_cookieHeader != null) {
      headers['Cookie'] = _cookieHeader!;
    }
    return headers;
  }

  Future<bool> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/api/method/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'usr': username, 'pwd': password}),
    );

    if (response.statusCode == 200) {
      final rawCookies = response.headers['set-cookie'];
      if (rawCookies != null) {
        final parts = rawCookies.split(RegExp(r',(?=[a-zA-Z0-9_]+=)'));
        final cookieList = <String>[];
        for (final p in parts) {
          final cookieVal = p.split(';').first.trim();
          if (cookieVal.isNotEmpty) {
            cookieList.add(cookieVal);
          }
        }
        _cookieHeader = cookieList.join('; ');
      }

      final prefs = await SharedPreferences.getInstance();
      if (_cookieHeader != null) {
        await prefs.setString('saved_cookies', _cookieHeader!);
      }

      await fetchEmployeeProfile(username);
      return true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Неверный логин или пароль');
    }
  }

  Future<void> logout() async {
    try {
      await http.get(
        Uri.parse('$baseUrl/api/method/logout'),
        headers: _getHeaders(),
      );
    } catch (_) {}
    _cookieHeader = null;
    _currentEmployee = null;
    _cachedTasks = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_cookies');
    await prefs.remove('saved_employee');
  }

  Future<Map<String, dynamic>?> fetchEmployeeProfile(String userEmail) async {
    final filter = jsonEncode([['user_id', '=', userEmail]]);
    final fields = jsonEncode([
      'name',
      'employee_name',
      'company',
      'custom_iin',
      'status',
      'date_of_joining',
      'designation',
      'department',
      'image'
    ]);

    final url = Uri.parse('$baseUrl/api/resource/Employee?filters=$filter&fields=$fields');
    final response = await http.get(url, headers: _getHeaders());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final list = json['data'] as List?;
      if (list != null && list.isNotEmpty) {
        _currentEmployee = list.first as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_employee', jsonEncode(_currentEmployee));
        return _currentEmployee;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> submitCheckin({
    required String logType,
    required double latitude,
    required double longitude,
  }) async {
    if (_currentEmployee == null) {
      throw Exception('Профиль сотрудника не найден');
    }

    final empId = _currentEmployee!['name'];
    final now = DateTime.now();
    final formattedTime =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final url = Uri.parse('$baseUrl/api/resource/Employee%20Checkin');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'employee': empId,
        'log_type': logType,
        'time': formattedTime,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data'] as Map<String, dynamic>;
    } else {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Ошибка при отправке отметки');
    }
  }

  Future<List<Map<String, dynamic>>> getCheckinHistory({int limit = 10}) async {
    if (_currentEmployee == null) return [];

    final empId = _currentEmployee!['name'];
    final filter = jsonEncode([['employee', '=', empId]]);
    final fields = jsonEncode(['name', 'log_type', 'time', 'latitude', 'longitude']);

    final url = Uri.parse(
        '$baseUrl/api/resource/Employee%20Checkin?filters=$filter&fields=$fields&order_by=time desc&limit_page_length=$limit');
    final response = await http.get(url, headers: _getHeaders());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return (json['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // --- Task Management (Kanji Reference Style) ---

  List<TaskItem> _getDefaultSeedTasks() {
    return [
      TaskItem(
        id: 'task-1',
        title: 'Feature Prioritization',
        description: 'Приоритизация кадровых модулей и грейдов сотрудников в системе Link HR. Проработка требований с тимлидом и финансовым отделом.',
        date: '11/08/2024',
        status: 'Completed',
        assignees: ['Dimas', 'Galih', 'Putra'],
        subtasks: [
          SubtaskItem(title: 'Собрать требования от HR-отдела', isCompleted: true),
          SubtaskItem(title: 'Утвердить матрицу должностей и окладов', isCompleted: true),
          SubtaskItem(title: 'Финальный аудит регламентов РК', isCompleted: true),
        ],
        attachments: [
          AttachmentItem(name: 'HR_Requirements.pdf', type: 'PDF', size: '1.4 MB'),
          AttachmentItem(name: 'Grades_Matrix.png', type: 'PNG', size: '920 KB'),
        ],
      ),
      TaskItem(
        id: 'task-2',
        title: 'Product Feature Update',
        description: 'Обновление мобильного кабинета: учет отпусков (24 дня) и расчетных листков с налогами РК (ОПВ, ВОСМС, ИПН).',
        date: '24/12/2024',
        status: 'Completed',
        assignees: ['Aisha', 'Serik'],
        subtasks: [
          SubtaskItem(title: 'Интеграция формулы налогов РК 2026', isCompleted: true),
          SubtaskItem(title: 'Формирование расчетных листков', isCompleted: true),
        ],
        attachments: [
          AttachmentItem(name: 'KZ_Tax_Specs.pdf', type: 'PDF', size: '2.1 MB'),
        ],
      ),
      TaskItem(
        id: 'task-3',
        title: 'Content Strategy Planning',
        description: 'Формирование шаблонов кадровых приказов и уведомлений сотрудников об отпусках и премиях.',
        date: '16/04/2025',
        status: 'In Progress',
        assignees: ['Dimas', 'Putra', 'Aisha'],
        subtasks: [
          SubtaskItem(title: 'Шаблоны приказов о приеме на работу', isCompleted: true),
          SubtaskItem(title: 'Шаблоны приказов о премировании', isCompleted: false),
          SubtaskItem(title: 'Согласование с юридическим отделом', isCompleted: false),
        ],
        attachments: [
          AttachmentItem(name: 'Orders_Draft.pdf', type: 'PDF', size: '850 KB'),
        ],
      ),
      TaskItem(
        id: 'task-4',
        title: 'Wireframe Development',
        description: 'Create a wireframe for the mobile app screens, focusing on user flow and responsive design for mobile check-in, tasks, and document approval...',
        date: '03/01/2024',
        status: 'In Progress',
        assignees: ['Dimas', 'Galih', 'Putra'],
        subtasks: [
          SubtaskItem(title: 'Review with the team', isCompleted: true),
          SubtaskItem(title: 'Create Low-Fidelity Wireframe', isCompleted: true),
          SubtaskItem(title: 'Develop High-Fidelity Wireframe', isCompleted: false),
          SubtaskItem(title: 'Final Review and Approval', isCompleted: false),
        ],
        attachments: [
          AttachmentItem(name: 'Wireframe_Guide.pdf', type: 'PDF', size: '1.2 MB'),
          AttachmentItem(name: 'Homepage_Wireframe.png', type: 'PNG', size: '800 KB'),
          AttachmentItem(name: 'Task_Timeline.rar', type: 'RAR', size: '500 KB'),
        ],
      ),
      TaskItem(
        id: 'task-5',
        title: 'Design Enhancement',
        description: 'Финальная полировка дизайн-системы, оптимизация контраста шрифтов и интерактивных состояний карточек.',
        date: '08/01/2024',
        status: 'On Hold',
        assignees: ['Galih', 'Putra'],
        subtasks: [
          SubtaskItem(title: 'Проверка цветовых контрастов WCAG', isCompleted: true),
          SubtaskItem(title: 'Аудит скруглений и теней карточек', isCompleted: false),
        ],
        attachments: [
          AttachmentItem(name: 'Design_System_Spec.pdf', type: 'PDF', size: '3.4 MB'),
        ],
      ),
    ];
  }

  Future<List<TaskItem>> getTasks() async {
    if (_cachedTasks != null && _cachedTasks!.isNotEmpty) {
      return _cachedTasks!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedTasksJson = prefs.getString('saved_kanji_tasks');

    List<TaskItem> tasks = [];
    if (savedTasksJson != null) {
      try {
        final list = jsonDecode(savedTasksJson) as List;
        tasks = list.map((e) => TaskItem.fromJson(e)).toList();
      } catch (_) {}
    }

    if (tasks.isEmpty) {
      tasks = _getDefaultSeedTasks();
    }

    // Try fetching from Frappe ToDo and merge
    try {
      final url = Uri.parse(
          '$baseUrl/api/resource/ToDo?fields=%5B%22name%22,%22description%22,%22status%22,%22date%22%5D&order_by=creation%20desc&limit_page_length=20');
      final response = await http.get(url, headers: _getHeaders());
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final remoteTodos = json['data'] as List?;
        if (remoteTodos != null) {
          for (final todo in remoteTodos) {
            final name = todo['name'];
            final desc = todo['description'] ?? 'Задача';
            final statusStr = todo['status'] == 'Closed' ? 'Completed' : 'In Progress';
            if (!tasks.any((t) => t.id == name)) {
              tasks.insert(
                0,
                TaskItem(
                  id: name,
                  title: desc.toString().split(':').first,
                  description: desc,
                  date: todo['date'] ?? '12/09/2026',
                  status: statusStr,
                  assignees: ['Серик Ахметов', 'HR Team'],
                  subtasks: [
                    SubtaskItem(title: 'Выполнить поручение', isCompleted: statusStr == 'Completed'),
                    SubtaskItem(title: 'Отправить отчет руководителю', isCompleted: statusStr == 'Completed'),
                  ],
                  attachments: [
                    AttachmentItem(name: 'Assignment_Doc.pdf', type: 'PDF', size: '1.1 MB'),
                  ],
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    _cachedTasks = tasks;
    await _saveTasksToPrefs(tasks);
    return tasks;
  }

  Future<void> _saveTasksToPrefs(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString('saved_kanji_tasks', jsonStr);
  }

  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    final tasks = await getTasks();
    final idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      tasks[idx].status = newStatus;
      await _saveTasksToPrefs(tasks);
    }

    // Also try updating Frappe ToDo if it was created there
    try {
      final remoteStatus = newStatus == 'Completed' ? 'Closed' : 'Open';
      final url = Uri.parse('$baseUrl/api/resource/ToDo/$taskId');
      await http.put(
        url,
        headers: _getHeaders(),
        body: jsonEncode({'status': remoteStatus}),
      );
    } catch (_) {}
  }

  Future<void> toggleSubtask(String taskId, int subtaskIndex, bool isCompleted) async {
    final tasks = await getTasks();
    final idx = tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1 && subtaskIndex < tasks[idx].subtasks.length) {
      tasks[idx].subtasks[subtaskIndex].isCompleted = isCompleted;
      // Auto-update task status if all subtasks are completed
      final allDone = tasks[idx].subtasks.every((s) => s.isCompleted);
      if (allDone) {
        tasks[idx].status = 'Completed';
      }
      await _saveTasksToPrefs(tasks);
    }
  }

  Future<TaskItem> createTask({
    required String title,
    required String description,
    required String dueDate,
    required String status,
    required List<String> subtasks,
  }) async {
    String taskId = 'task-${DateTime.now().millisecondsSinceEpoch}';

    // Try creating on Frappe
    try {
      final url = Uri.parse('$baseUrl/api/resource/ToDo');
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({
          'description': '$title: $description',
          'status': status == 'Completed' ? 'Closed' : 'Open',
          'priority': 'Medium',
          'allocated_to': 'employee@link.kz',
        }),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        taskId = json['data']['name'] ?? taskId;
      }
    } catch (_) {}

    final newTask = TaskItem(
      id: taskId,
      title: title,
      description: description,
      date: dueDate,
      status: status,
      assignees: ['Серик Ахметов', 'Dimas'],
      subtasks: subtasks.map((s) => SubtaskItem(title: s, isCompleted: false)).toList(),
      attachments: [
        AttachmentItem(name: 'Task_Brief.pdf', type: 'PDF', size: '950 KB'),
      ],
    );

    final tasks = await getTasks();
    tasks.insert(0, newTask);
    await _saveTasksToPrefs(tasks);
    return newTask;
  }

  // --- Kazakhstani HR Documents (Contracts, Orders, Timesheets) ---

  Future<List<Map<String, dynamic>>> getLaborContracts() async {
    try {
      final filter = _currentEmployee != null
          ? jsonEncode([['employee', '=', _currentEmployee!['name']]])
          : '[]';
      final url = Uri.parse(
          '$baseUrl/api/resource/KZ%20Labor%20Contract?filters=$filter&fields=%5B%22name%22,%22contract_number%22,%22contract_date%22,%22contract_type%22,%22probation_period%22,%22monthly_salary%22,%22status%22%5D&order_by=contract_date%20desc');
      final response = await http.get(url, headers: _getHeaders());
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = (json['data'] as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // Clean standard default KZ contract for Serik Akhmetov
    return [
      {
        'name': 'KZ-CON-2026-001',
        'contract_number': 'ТД-№ 48/2026',
        'contract_date': '2026-01-05',
        'contract_type': 'На неопределенный срок (ст. 30 ТК РК)',
        'probation_period': '3 месяца',
        'monthly_salary': 450000,
        'status': 'Действующий',
        'enbek_kz_status': 'Зарегистрирован в ЕНСТ',
        'position': 'Ведущий специалист кадрового администрирования',
      }
    ];
  }

  Future<List<Map<String, dynamic>>> getPersonnelOrders() async {
    try {
      final filter = _currentEmployee != null
          ? jsonEncode([['employee', '=', _currentEmployee!['name']]])
          : '[]';
      final url = Uri.parse(
          '$baseUrl/api/resource/KZ%20Personnel%20Order?filters=$filter&fields=%5B%22name%22,%22order_number%22,%22order_date%22,%22order_type%22,%22title%22,%22status%22%5D&order_by=order_date%20desc');
      final response = await http.get(url, headers: _getHeaders());
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = (json['data'] as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return [
      {
        'name': 'KZ-ORD-2026-003',
        'order_number': 'П-14/лс',
        'order_date': '2026-02-10',
        'order_type': 'О премировании',
        'title': 'О выплате квартальной премии за высокие показатели',
        'status': 'Утвержден',
        'amount': '120 000 ₸',
      },
      {
        'name': 'KZ-ORD-2026-001',
        'order_number': 'П-02/лс',
        'order_date': '2026-01-05',
        'order_type': 'О приеме на работу',
        'title': 'О приеме на должность специалиста с окладом 450 000 ₸',
        'status': 'Утвержден',
        'amount': '',
      }
    ];
  }

  Future<List<Map<String, dynamic>>> getTimesheets() async {
    try {
      final filter = _currentEmployee != null
          ? jsonEncode([['employee', '=', _currentEmployee!['name']]])
          : '[]';
      final url = Uri.parse(
          '$baseUrl/api/resource/KZ%20Timesheet?filters=$filter&fields=%5B%22name%22,%22month%22,%22year%22,%22total_working_hours%22,%22total_working_days%22,%22status%22%5D&order_by=creation%20desc');
      final response = await http.get(url, headers: _getHeaders());
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = (json['data'] as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return [
      {
        'name': 'TS-2026-02',
        'period': 'Февраль 2026',
        'working_days': 20,
        'working_hours': 160,
        'actual_hours': 160,
        'status': 'Закрыт',
        'rate': '100%',
      },
      {
        'name': 'TS-2026-01',
        'period': 'Январь 2026',
        'working_days': 21,
        'working_hours': 168,
        'actual_hours': 168,
        'status': 'Закрыт',
        'rate': '100%',
      }
    ];
  }

  // --- Leaves & Salary ---

  Future<List<Map<String, dynamic>>> getLeaveApplications() async {
    if (_currentEmployee == null) return [];

    final empId = _currentEmployee!['name'];
    final filter = jsonEncode([['employee', '=', empId]]);
    final fields = jsonEncode([
      'name',
      'leave_type',
      'from_date',
      'to_date',
      'total_leave_days',
      'status',
      'description'
    ]);

    final url = Uri.parse(
        '$baseUrl/api/resource/Leave%20Application?filters=$filter&fields=$fields&order_by=from_date desc');
    final response = await http.get(url, headers: _getHeaders());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return (json['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<String>> getLeaveTypes() async {
    final url = Uri.parse('$baseUrl/api/resource/Leave%20Type?fields=%5B%22name%22%5D');
    final response = await http.get(url, headers: _getHeaders());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final list = (json['data'] as List).map((e) => e['name'].toString()).toList();
      return list;
    }
    return [];
  }

  Future<bool> submitLeaveApplication({
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    if (_currentEmployee == null) return false;

    final empId = _currentEmployee!['name'];
    final url = Uri.parse('$baseUrl/api/resource/Leave%20Application');
    final response = await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode({
        'employee': empId,
        'leave_type': leaveType,
        'from_date': fromDate,
        'to_date': toDate,
        'description': reason,
        'company': _currentEmployee!['company'] ?? 'Test',
      }),
    );

    return response.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> getSalarySlips() async {
    if (_currentEmployee == null) return [];

    final empId = _currentEmployee!['name'];
    final filter = jsonEncode([['employee', '=', empId]]);
    final fields = jsonEncode([
      'name',
      'start_date',
      'end_date',
      'gross_pay',
      'total_deduction',
      'net_pay',
      'status'
    ]);

    final url = Uri.parse(
        '$baseUrl/api/resource/Salary%20Slip?filters=$filter&fields=$fields&order_by=start_date desc');
    final response = await http.get(url, headers: _getHeaders());

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return (json['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
