import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/session.dart';
import 'core/app_language.dart';
import 'core/theme.dart';
import 'features/auth/auth_screens.dart';
import 'features/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = AppLanguageController.instance.current.code;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(const LinkApp());
  // Locale data is not allowed to delay the first Flutter frame on iOS.
  initializeDateFormatting('ru');
  initializeDateFormatting('kk');
}

class LinkApp extends StatefulWidget {
  const LinkApp({super.key});

  @override
  State<LinkApp> createState() => _LinkAppState();
}

class _LinkAppState extends State<LinkApp> {
  @override
  void initState() {
    super.initState();
    // A saved language must never delay the first native frame.
    AppLanguageController.instance.restore();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguageController.instance,
      builder: (context, _) => MaterialApp(
        title: 'Link',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: Locale(AppLanguageController.instance.current.code),
        supportedLocales: const [Locale('ru'), Locale('kk')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const RootGate(),
      ),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> with WidgetsBindingObserver {
  final _session = Session.instance;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      await _session.restore().timeout(const Duration(seconds: 6));
      if (_session.phase != SessionPhase.signedOut) {
        _session.refresh().catchError((_) {});
      }
    } catch (_) {
      // The sign-in screen remains available even if local iOS storage is slow.
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _session.biometricLock &&
        _session.phase == SessionPhase.ready) {
      _session.unlocked = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final Widget screen = _starting
            ? const BootScreen()
            : switch (_session.phase) {
                SessionPhase.signedOut => const LoginScreen(),
                SessionPhase.loading => const BootScreen(),
                SessionPhase.noEmployee => const NoEmployeeScreen(),
                SessionPhase.ready =>
                  _session.biometricLock && !_session.unlocked
                      ? const LockScreen()
                      : const Shell(),
              };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutQuart,
          child: KeyedSubtree(key: ValueKey(screen.runtimeType), child: screen),
        );
      },
    );
  }
}
