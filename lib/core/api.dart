import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'fmt.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.type});

  final String message;
  final int? statusCode;
  final String? type;

  @override
  String toString() => message;
}

typedef Json = Map<String, dynamic>;

/// Thin client over the Frappe REST API using the session cookie,
/// the same auth the HRMS PWA relies on.
class Api {
  Api._();

  static final Api instance = Api._();

  /// Each client company has its own site: <code>.hr.behruz.online.
  static const domainRoot = 'hr.behruz.online';
  static const defaultServer = 'https://$domainRoot';
  static String baseUrl = defaultServer;
  static const _cookieKey = 'link.cookies';
  static const _serverKey = 'link.server';

  Future<void> setServer(String server) async {
    baseUrl = server;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, server);
  }

  static const _timeout = Duration(seconds: 30);

  final _client = http.Client();
  final Map<String, String> _jar = {};

  /// Invoked once when the server reports the session is gone.
  void Function()? onSessionExpired;

  bool get hasSession {
    final sid = _jar['sid'];
    return sid != null && sid.isNotEmpty && sid != 'Guest';
  }

  Map<String, String> get authHeaders => _jar.isEmpty
      ? const {}
      : {'Cookie': _jar.entries.map((e) => '${e.key}=${e.value}').join('; ')};

  String fileUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_serverKey);
    // Installs from before multi-company used the bare IP of our own site.
    baseUrl = saved == null || saved.contains('186.240.157.112')
        ? defaultServer
        : saved;
    final raw = prefs.getString(_cookieKey);
    if (raw == null) return;
    try {
      _jar.addAll((jsonDecode(raw) as Map).cast<String, String>());
    } catch (_) {}
  }

  Future<void> clear() async {
    _jar.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookieKey);
  }

  /// One entrance for every company: the owner site finds the person's company by email,
  /// verifies the password there and returns that company's server and session.
  Future<void> login(String usr, String pwd) async {
    _jar.clear();
    final res = await _send(
      () => _client.post(
        Uri.parse('$defaultServer/api/method/link.link_saas.directory.login'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'usr': usr, 'pwd': pwd, 'device': 'mobile'}),
      ),
    );
    if (res.statusCode == 429) {
      throw ApiException(
        'Слишком много попыток входа. Подождите 10 минут.',
        statusCode: 429,
      );
    }
    if (res.statusCode != 200) {
      final err = _error(res);
      throw ApiException(
        res.statusCode == 401 || res.statusCode == 403
            ? 'Неверный email или пароль'
            : err.message,
        statusCode: res.statusCode,
      );
    }
    final message =
        (jsonDecode(res.body) as Map)['message'] as Map? ?? const {};
    await setServer(message['server']?.toString() ?? defaultServer);
    final cookies = message['cookies'];
    if (cookies is Map) {
      _jar.addAll(cookies.map((k, v) => MapEntry(k.toString(), v.toString())));
    } else {
      _absorb(res);
    }
    await _persist();
  }

  Future<void> requestPasswordReset(String email) async {
    await _send(
      () => _client.post(
        Uri.parse(
          '$defaultServer/api/method/link.link_saas.directory.reset_password',
        ),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'user': email}),
      ),
    );
  }

  Future<void> logout() async {
    try {
      await _client
          .post(Uri.parse('$baseUrl/api/method/logout'), headers: authHeaders)
          .timeout(_timeout);
    } catch (_) {}
    await clear();
  }

  /// Calls a whitelisted python method and returns its `message`.
  Future<dynamic> call(String method, [Json? args]) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/api/method/$method'),
        headers: {..._jsonHeaders, ...authHeaders},
        body: jsonEncode(args ?? const {}),
      ),
    );
    return _unwrap(res)['message'];
  }

  Future<List<Json>> list(
    String doctype, {
    List<String> fields = const ['name'],
    Object? filters,
    Object? orFilters,
    String? orderBy,
    int limit = 20,
    int start = 0,
  }) async {
    final data = await call('frappe.client.get_list', {
      'doctype': doctype,
      'fields': fields,
      'filters': filters,
      'or_filters': orFilters,
      'order_by': orderBy,
      'limit_start': start,
      'limit_page_length': limit,
    });
    return (data as List? ?? const []).cast<Json>();
  }

  Future<Json> doc(String doctype, String name) async {
    final res = await _send(
      () => _client.get(
        Uri.parse(
          '$baseUrl/api/resource/${Uri.encodeComponent(doctype)}/${Uri.encodeComponent(name)}',
        ),
        headers: {..._jsonHeaders, ...authHeaders},
      ),
    );
    return (_unwrap(res)['data'] as Map).cast<String, dynamic>();
  }

  Future<Json> insert(Json doc) async =>
      _asJson(await call('frappe.client.insert', {'doc': doc}));

  Future<Json> save(Json doc) async =>
      _asJson(await call('frappe.client.save', {'doc': doc}));

  Future<Json> setValue(String doctype, String name, Json values) async =>
      _asJson(
        await call('frappe.client.set_value', {
          'doctype': doctype,
          'name': name,
          'fieldname': values,
        }),
      );

  Future<Json> submit(Json doc) async =>
      _asJson(await call('frappe.client.submit', {'doc': doc}));

  Future<void> cancel(String doctype, String name) =>
      call('frappe.client.cancel', {'doctype': doctype, 'name': name});

  Future<void> delete(String doctype, String name) =>
      call('frappe.client.delete', {'doctype': doctype, 'name': name});

  /// Multipart upload through Frappe's `upload_file`, which accepts any file
  /// type for signed-in users (audio included).
  Future<Json> uploadFile({
    required List<int> bytes,
    required String fileName,
    String? doctype,
    String? docname,
    bool isPrivate = true,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/api/method/upload_file'),
          )
          ..headers.addAll({'Accept': 'application/json', ...authHeaders})
          ..fields.addAll({
            'doctype': ?doctype,
            'docname': ?docname,
            'is_private': isPrivate ? '1' : '0',
          })
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName),
          );
    final res = await _send(
      () async => http.Response.fromStream(await _client.send(request)),
    );
    return _asJson(_unwrap(res)['message']);
  }

  Future<void> addTag(String doctype, String name, String tag) => call(
    'frappe.desk.doctype.tag.tag.add_tag',
    {'tag': tag, 'dt': doctype, 'dn': name},
  );

  Future<void> removeTag(String doctype, String name, String tag) => call(
    'frappe.desk.doctype.tag.tag.remove_tag',
    {'tag': tag, 'dt': doctype, 'dn': name},
  );

  Future<Uint8List> download(String pathOrUrl) async {
    final res = await _send(
      () => _client.get(Uri.parse(fileUrl(pathOrUrl)), headers: authHeaders),
    );
    if (res.statusCode != 200) throw _error(res);
    return res.bodyBytes;
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Json _asJson(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final res = await request().timeout(_timeout);
      _absorb(res);
      return res;
    } on TimeoutException {
      throw ApiException(
        'Сервер не отвечает. Проверьте подключение к интернету.',
      );
    } on SocketException {
      throw ApiException('Нет соединения с сервером. Проверьте интернет.');
    } on http.ClientException {
      throw ApiException('Нет соединения с сервером. Проверьте интернет.');
    }
  }

  Json _unwrap(http.Response res) {
    if (res.statusCode == 200) {
      final body = utf8.decode(res.bodyBytes);
      if (body.isEmpty) return {};
      final decoded = jsonDecode(body);
      return decoded is Map
          ? decoded.cast<String, dynamic>()
          : {'message': decoded};
    }
    final err = _error(res);
    final sessionGone =
        res.statusCode == 401 ||
        (res.statusCode == 403 &&
            (err.type == 'SessionExpired' || err.type == 'CSRFTokenError')) ||
        (res.statusCode == 403 && _jar['sid'] == 'Guest');
    if (sessionGone && onSessionExpired != null) onSessionExpired!();
    throw err;
  }

  ApiException _error(http.Response res) {
    var message = switch (res.statusCode) {
      403 => 'Недостаточно прав для этого действия',
      404 => 'Запись не найдена',
      417 => 'Проверьте заполнение полей',
      >= 500 => 'Ошибка сервера. Попробуйте позже.',
      _ => 'Ошибка запроса (${res.statusCode})',
    };
    String? type;
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      type = j['exc_type']?.toString();
      final serverMessages = j['_server_messages'];
      if (serverMessages is String) {
        final items = (jsonDecode(serverMessages) as List)
            .map((raw) {
              try {
                final m = jsonDecode(raw.toString());
                return m is Map
                    ? (m['message'] ?? '').toString()
                    : m.toString();
              } catch (_) {
                return raw.toString();
              }
            })
            .where((m) => m.trim().isNotEmpty);
        if (items.isNotEmpty) message = items.join('\n');
      } else if (j['message'] is String &&
          (j['message'] as String).isNotEmpty) {
        message = j['message'];
      } else if (j['exception'] is String) {
        final ex = j['exception'] as String;
        message = ex.contains(':')
            ? ex.substring(ex.indexOf(':') + 1).trim()
            : ex;
      }
    } catch (_) {}
    return ApiException(
      stripHtml(message),
      statusCode: res.statusCode,
      type: type,
    );
  }

  void _absorb(http.Response res) {
    final raw = res.headers['set-cookie'];
    if (raw == null) return;
    // package:http folds multiple Set-Cookie headers into one comma-joined string.
    for (final part in raw.split(RegExp(r',(?=\s*[A-Za-z0-9_\-]+=)'))) {
      final pair = part.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      _jar[pair.substring(0, eq)] = pair.substring(eq + 1);
    }
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookieKey, jsonEncode(_jar));
  }
}
