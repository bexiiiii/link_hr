import 'package:intl/intl.dart';

abstract final class Fmt {
  static DateTime? parse(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 11/08/2024, the reference's card date format.
  static String date(Object? value) {
    final d = parse(value);
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
  }

  /// 5 сент.
  static String dayMonth(Object? value) {
    final d = parse(value);
    return d == null ? '' : DateFormat('d MMM', 'ru').format(d);
  }

  /// 5 сентября 2026
  static String long(Object? value) {
    final d = parse(value);
    return d == null ? '' : DateFormat('d MMMM y', 'ru').format(d);
  }

  /// вт, 05 дек.
  static String weekdayDate(Object? value) {
    final d = parse(value);
    return d == null ? '' : DateFormat('EE, dd MMM', 'ru').format(d);
  }

  static String todayLine(DateTime d) =>
      _cap(DateFormat('EEEE, d MMMM', 'ru').format(d));

  static String monthYear(DateTime d) =>
      _cap(DateFormat('LLLL y', 'ru').format(d));

  static String month(DateTime d) => _cap(DateFormat('LLLL', 'ru').format(d));

  static String time(Object? value) {
    final d = parse(value);
    return d == null ? '' : DateFormat('HH:mm').format(d);
  }

  static String clock(DateTime d) => DateFormat('HH:mm:ss').format(d);

  static String range(Object? from, Object? to) {
    final a = parse(from);
    final b = parse(to);
    if (a == null) return '';
    if (b == null) return '${dayMonth(a)} – без срока';
    if (dateOnly(a) == dateOnly(b)) return dayMonth(a);
    return '${dayMonth(a)} – ${dayMonth(b)}';
  }

  static String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String isoDateTime(DateTime d) =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(d);

  static String relative(Object? value) {
    final d = parse(value);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays == 1) return 'вчера';
    if (diff.inDays < 7)
      return '${diff.inDays} ${plural(diff.inDays, 'день', 'дня', 'дней')} назад';
    return date(d);
  }

  static num number(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String symbol(String? currency) =>
      const {'KZT': '₸', 'RUB': '₽', 'USD': r'$', 'EUR': '€'}[currency] ??
      (currency ?? '₸');

  static String money(Object? value, [String? currency]) {
    final n = number(value);
    final digits = n % 1 == 0 ? 0 : 2;
    return NumberFormat.currency(
      locale: 'ru',
      symbol: symbol(currency),
      decimalDigits: digits,
    ).format(n);
  }

  static String decimal(Object? value) {
    final n = number(value);
    return n % 1 == 0
        ? n.toInt().toString()
        : n.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String days(Object? value) {
    final n = number(value);
    final whole = n % 1 == 0;
    final word = whole ? plural(n.toInt(), 'день', 'дня', 'дней') : 'дня';
    return '${decimal(n)} $word';
  }

  static String plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  static String bytes(num? size) {
    if (size == null || size <= 0) return 'Файл';
    if (size < 1024) return '${size.toInt()} Б';
    if (size < 1024 * 1024) return '${(size / 1024).round()} КБ';
    return '${(size / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} МБ';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

String stripHtml(String? html) {
  if (html == null) return '';
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|li|h\d)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String escapeHtml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

const _statusLabels = {
  'Open': 'На рассмотрении',
  'Approved': 'Одобрено',
  'Rejected': 'Отклонено',
  'Cancelled': 'Отменено',
  'Draft': 'Черновик',
  'Submitted': 'Проведено',
  'Paid': 'Выплачено',
  'Unpaid': 'Не выплачено',
  'Claimed': 'Закрыт отчётом',
  'Returned': 'Возвращено',
  'Partly Claimed and Returned': 'Частично закрыт',
  'Present': 'Присутствие',
  'Absent': 'Отсутствие',
  'On Leave': 'Отпуск',
  'Half Day': 'Полдня',
  'Work From Home': 'Удалённо',
  'On Duty': 'Служебная задача',
  'Holiday': 'Выходной',
  'Closed': 'Выполнено',
  'Active': 'Активно',
  'Inactive': 'Неактивно',
  'Completed': 'Выполнено',
  'In Progress': 'В работе',
  'On Hold': 'Отложено',
  'Low': 'Низкий',
  'Medium': 'Средний',
  'High': 'Высокий',
  'IN': 'Приход',
  'OUT': 'Уход',
};

String statusLabel(String? status) => _statusLabels[status] ?? (status ?? '');
