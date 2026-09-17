import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Light green direction (DESIGN.md): near-white neutrals tinted toward the
/// brand green, one deep green accent for primary actions and the active tab.
abstract final class AppColors {
  static const bg = Color(0xFFF4F5F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF7F8F7);
  static const line = Color(0xFFE9EBEA);

  static const ink = Color(0xFF141816);
  static const ink2 = Color(0xFF4A514D);
  static const ink3 = Color(0xFF6E7571);
  static const ink4 = Color(0xFFBFC5C2);

  /// Brand green: primary buttons, active tab, clock button, links.
  static const green = Color(0xFF0F8A62);
  static const greenDeep = Color(0xFF0B6F4F);
  static const greenSoft = Color(0xFFE6F4EE);
  static const greenGlow = Color(0xFFBFE6D6);

  /// Legacy accent name: every former blue/violet accent now resolves to the brand green.
  static const violet = green;
  static const violetSoft = greenSoft;

  /// Legacy "graphite" name: dark ink for icons and strong text.
  static const charcoal = Color(0xFF1F2522);

  static const red = Color(0xFFD94545);
  static const redSoft = Color(0xFFFCEBEB);
  static const amber = Color(0xFFD9822B);
  static const amberSoft = Color(0xFFFDF0E1);
  static const warn = Color(0xFFE9B949);
  static const warnSoft = Color(0xFFFDF6E3);
  static const plum = Color(0xFF7B5CD6);
  static const plumSoft = Color(0xFFF1ECFC);

  static const chip = Color(0xFFEEF0EF);
  static const chipDot = Color(0xFFCDD2CF);
  static const camera = Color(0xFF0C0F0E);
}

const kFont = 'Onest';

abstract final class AppText {
  static const display = TextStyle(
      fontFamily: kFont, fontSize: 32, height: 1.1, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: AppColors.ink);
  static const title = TextStyle(
      fontFamily: kFont, fontSize: 22, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.ink);
  static const heading =
      TextStyle(fontFamily: kFont, fontSize: 18, height: 1.25, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const cardTitle =
      TextStyle(fontFamily: kFont, fontSize: 16, height: 1.3, fontWeight: FontWeight.w500, color: AppColors.ink);
  static const body = TextStyle(fontFamily: kFont, fontSize: 15, height: 1.45, fontWeight: FontWeight.w400, color: AppColors.ink);
  static const bodyStrong =
      TextStyle(fontFamily: kFont, fontSize: 15, height: 1.4, fontWeight: FontWeight.w500, color: AppColors.ink);
  static const label = TextStyle(fontFamily: kFont, fontSize: 13, height: 1.35, fontWeight: FontWeight.w400, color: AppColors.ink2);
  static const caption =
      TextStyle(fontFamily: kFont, fontSize: 12, height: 1.3, fontWeight: FontWeight.w400, color: AppColors.ink3);
  static const number = TextStyle(
    fontFamily: kFont,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const clock = TextStyle(
    fontFamily: kFont,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

abstract final class AppRadius {
  static const card = 18.0;
  static const tile = 14.0;
  static const field = 12.0;
  static const pill = 999.0;
}

/// The one soft shadow used for cards; the nav pill and clock button use [AppShadow.float].
abstract final class AppShadow {
  static const card = [BoxShadow(color: Color(0x0A141816), blurRadius: 12, offset: Offset(0, 2))];
  static const float = [BoxShadow(color: Color(0x1A141816), blurRadius: 24, offset: Offset(0, 8))];
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
        Tone.green => AppColors.greenDeep,
        Tone.violet => AppColors.violet,
        Tone.dark => AppColors.charcoal,
        Tone.red => const Color(0xFFB83636),
        Tone.amber => const Color(0xFFA35F17),
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
    case 'черновик':
      return Tone.violet;
    case 'in progress':
      return Tone.amber;
    case 'rejected':
    case 'absent':
    case 'overdue':
    case 'on hold':
      return Tone.red;
    case 'cancelled':
    case 'on leave':
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
    fontFamily: kFont,
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
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: AppColors.green,
      textTheme: CupertinoTextThemeData(textStyle: TextStyle(fontFamily: kFont, fontSize: 16, color: AppColors.ink)),
    ),
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
