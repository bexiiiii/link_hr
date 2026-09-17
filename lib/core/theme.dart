import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Light-blue direction: clean white surfaces and one reliable blue action.
/// Legacy token names intentionally resolve to blue so every existing feature
/// keeps the same visual language without scattered one-off colors.
abstract final class AppColors {
  static const bg = Color(0xFFF5F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F5FB);
  static const line = Color(0xFFE1E9F2);

  static const ink = Color(0xFF122033);
  static const ink2 = Color(0xFF43546A);
  static const ink3 = Color(0xFF66788E);
  static const ink4 = Color(0xFFB8C5D3);

  /// Brand blue: primary buttons, active tab, check-in and links.
  static const blue = Color(0xFF1769E0);
  static const blueDeep = Color(0xFF0D54B6);
  static const blueSoft = Color(0xFFE7F0FF);
  static const blueGlow = Color(0xFFC9DDFF);

  static const green = blue;
  static const greenDeep = blueDeep;
  static const greenSoft = blueSoft;
  static const greenGlow = blueGlow;
  static const violet = blue;
  static const violetSoft = blueSoft;

  /// Legacy "graphite" name: dark ink for icons and strong text.
  static const charcoal = Color(0xFF1B2B40);

  static const red = Color(0xFFD94545);
  static const redSoft = Color(0xFFFCEBEB);
  static const amber = Color(0xFFD9822B);
  static const amberSoft = Color(0xFFFDF0E1);
  static const warn = Color(0xFFE9B949);
  static const warnSoft = Color(0xFFFDF6E3);
  static const plum = blue;
  static const plumSoft = blueSoft;

  static const chip = Color(0xFFEAF0F7);
  static const chipDot = Color(0xFFC8D3E0);
  static const camera = Color(0xFF0C0F0E);
}

const kFont = 'Onest';

abstract final class AppText {
  static const display = TextStyle(
    fontFamily: kFont,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: AppColors.ink,
  );
  static const title = TextStyle(
    fontFamily: kFont,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );
  static const heading = TextStyle(
    fontFamily: kFont,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const cardTitle = TextStyle(
    fontFamily: kFont,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontFamily: kFont,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );
  static const bodyStrong = TextStyle(
    fontFamily: kFont,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );
  static const label = TextStyle(
    fontFamily: kFont,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.ink2,
  );
  static const caption = TextStyle(
    fontFamily: kFont,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: AppColors.ink3,
  );
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
  static const card = <BoxShadow>[];
  static const float = [
    BoxShadow(color: Color(0x1A122033), blurRadius: 16, offset: Offset(0, 6)),
  ];
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
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: kFont,
          fontSize: 16,
          color: AppColors.ink,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.violet,
      selectionHandleColor: AppColors.violet,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
