import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:link_mobile/services/api_service.dart';
import 'package:link_mobile/screens/login_screen.dart';
import 'package:link_mobile/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set iOS system bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize API service and load session if saved
  await ApiService().init();

  runApp(const LinkHRApp());
}

class LinkHRApp extends StatelessWidget {
  const LinkHRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Link HR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7052BA),
          primary: const Color(0xFF7052BA),
          secondary: const Color(0xFF4EBE71),
        ),
        useMaterial3: true,
        fontFamily: '.SF Pro Text',
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: ApiService().isLoggedIn
          ? const MainNavigationScreen()
          : const LoginScreen(),
    );
  }
}
