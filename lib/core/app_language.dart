import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-owned language setting. It is deliberately independent from the device
/// language so a company can keep Russian or Kazakh consistently on shared
/// work phones.
enum AppLanguage {
  russian('ru'),
  kazakh('kk');

  const AppLanguage(this.code);
  final String code;
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController._();

  static final instance = AppLanguageController._();
  static const _key = 'link.language';

  AppLanguage current = AppLanguage.russian;

  bool get isKazakh => current == AppLanguage.kazakh;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return;
    final next = AppLanguage.values.where((v) => v.code == saved).firstOrNull;
    if (next == null || next == current) return;
    current = next;
    Intl.defaultLocale = current.code;
    notifyListeners();
  }

  Future<void> set(AppLanguage next) async {
    if (next == current) return;
    current = next;
    Intl.defaultLocale = current.code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.code);
  }
}

/// Use for product strings that must be available before an API call returns.
/// Backend values (names, document types, statuses) remain unchanged.
String tx(String russian, String kazakh) =>
    AppLanguageController.instance.isKazakh ? kazakh : russian;
