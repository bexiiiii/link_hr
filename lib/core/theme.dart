import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Palette follows the Kanji task-management reference: porcelain ground,
/// white surfaces, emerald / violet / charcoal as the three status voices.
abstract final class AppColors {
  static const bg = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF7F8FA);
  static const line = Color(0xFFE8EAEE);

  static const ink = Color(0xFF1B1D23);
  static const ink2 = Color(0xFF4F535D);
  static const ink3 = Color(0xFF737884);
  static const ink4 = Color(0xFFC3C6CD);

  static const green = Color(0xFF34B35A);
  static const greenDeep = Color(0xFF1F8A45);
  static const greenSoft = Color(0xFFE8F6EC);
  /// Primary accent: links, selection, switches. Kept under the old name so
  /// every existing reference moves to the new palette.
  static const violet = Color(0xFF2F6FED);
  static const violetSoft = Color(0xFFEAF1FE);
  /// Graphite used for primary buttons, bell, active navigation.
  static const charcoal = Color(0xFF3D4047);
  static const red = Color(0xFFE5484D);
  static const redSoft = Color(0xFFFDECEC);
  /// Lateness and days off.
  static const amber = Color(0xFFE8832A);
  static const amberSoft = Color(0xFFFFF2E5);
  static const warn = Color(0xFFF2C94C);
  static const warnSoft = Color(0xFFFFF8E1);
  static const plum = Color(0xFF7B5CD6);
  static const plumSoft = Color(0xFFF1ECFC);

  static const chip = Color(0xFFEDEEF1);
  static const chipDot = Color(0xFFCDD0D6);
}

abstract final class AppText {
  static const display = TextStyle(
      fontSize: 28, height: 1.15, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.ink);
  static const title = TextStyle(
      fontSize: 22, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.ink);
  static const heading = TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const cardTitle = TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const body = TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w400, color: AppColors.ink);
  static const bodyStrong = TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500, color: AppColors.ink);
  static const label = TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w400, color: AppColors.ink2);
  static const caption = TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w400, color: AppColors.ink3);
  static const number = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}


abstract final class AppRadius {
  static const card = 12.0;
  static const tile = 12.0;
  static const field = 8.0;
}
enum Tone { green, violet, dark, red, amber, neutral }

extension ToneColors on Tone {
  Color get solid => switch (this) {
        Tone.green => AppColors.greenDeep,
        Tone.violet => AppColors.violet,
        Tone.dark => AppColors.charcoal,
        Tone.red => AppColors.red,
        Tone.amber => AppColors.amber,
        Tone.neutral => AppColors.chip,
      };

  Color get soft => switch (this) {
        Tone.green => AppColors.greenSoft,
        Tone.violet => AppColors.violetSoft,
        Tone.dark => AppColors.chip,
        Tone.red => AppColors.redSoft,
        Tone.amber => AppColors.amberSoft,
        Tone.neutral => AppColors.surfaceAlt,
      };

  Color get onSolid => this == Tone.neutral ? AppColors.ink2 : Colors.white;

  Color get ink => switch (this) {
        Tone.green => const Color(0xFF1F8A45),
        Tone.violet => AppColors.violet,
        Tone.dark => AppColors.charcoal,
        Tone.red => const Color(0xFFC2363B),
        Tone.amber => const Color(0xFFB45E12),
        Tone.neutral => AppColors.ink2,
      };
}

Tone toneForStatus(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'approved':
    case 'completed':
    case 'closed':
    case 'paid':
    case 'present':
    case 'submitted':
    case 'active':
    case 'claimed':
    case 'returned':
    case 'утвержден':
    case 'действующий':
    case 'закрыт':
      return Tone.green;
    case 'open':
    case 'draft':
    case 'pending':
    case 'unpaid':
    case 'work from home':
    case 'half day':
    case 'partly claimed and returned':
    case 'in progress':
    case 'черновик':
      return Tone.violet;
    case 'rejected':
    case 'absent':
    case 'overdue':
      return Tone.red;
    case 'cancelled':
    case 'on leave':
    case 'on hold':
    case 'inactive':
    case 'расторгнут':
    case 'отменен':
      return Tone.dark;
    case 'holiday':
      return Tone.amber;
    default:
      return Tone.neutral;
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      primary: AppColors.violet,
      secondary: AppColors.green,
      surface: AppColors.surface,
      error: AppColors.red,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    platform: TargetPlatform.iOS,
    cupertinoOverrideTheme: const CupertinoThemeData(primaryColor: AppColors.violet),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.violet,
      selectionHandleColor: AppColors.violet,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
  );
}
