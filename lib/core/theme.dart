import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Reference direction: quiet iOS-like white surfaces, near-black type and a
/// single orange action colour.  The old public token names remain so feature
/// screens do not drift into one-off palettes while they are being simplified.
abstract final class AppColors {
  static const bg = Color(0xFFF7F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F2F4);
  static const line = Color(0xFFE8E9EC);

  static const ink = Color(0xFF17181A);
  static const ink2 = Color(0xFF575A60);
  static const ink3 = Color(0xFF8E9198);
  static const ink4 = Color(0xFFC7C9CE);

  /// Primary action — the saturated orange in the supplied mobile references.
  static const blue = Color(0xFFFF9400);
  static const blueDeep = Color(0xFFE68100);
  static const blueSoft = Color(0xFFFFF0DC);
  static const blueGlow = Color(0xFFFFD8A0);

  /// Existing feature actions use these legacy aliases and now inherit orange.
  static const green = blue;
  static const greenDeep = blueDeep;
  static const greenSoft = blueSoft;
  static const greenGlow = blueGlow;

  /// Cool blue remains a secondary information colour (map, calendar, links).
  static const violet = Color(0xFF3478F6);
  static const violetSoft = Color(0xFFEAF1FF);

  /// Semantic status colours are deliberately independent from primary action.
  static const success = Color(0xFF16B978);
  static const successDeep = Color(0xFF0B9B60);
  static const successSoft = Color(0xFFE2F8EE);

  /// Legacy "graphite" name: dark ink for icons and strong text.
  static const charcoal = Color(0xFF1C1D20);

  static const red = Color(0xFFEF4444);
  static const redSoft = Color(0xFFFFE8E8);
  static const amber = Color(0xFFF0A13A);
  static const amberSoft = Color(0xFFFFF0D8);
  static const warn = Color(0xFFEAB308);
  static const warnSoft = Color(0xFFFFF8D6);
  static const plum = blue;
  static const plumSoft = blueSoft;

  static const chip = Color(0xFFF0F1F3);
  static const chipDot = Color(0xFFD0D2D7);
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
    BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 7)),
  ];
}

enum Tone { green, violet, dark, red, amber, neutral }

extension ToneColors on Tone {
  Color get solid => switch (this) {
    Tone.green => AppColors.successDeep,
    Tone.violet => AppColors.violet,
    Tone.dark => AppColors.charcoal,
    Tone.red => AppColors.red,
    Tone.amber => AppColors.amber,
    Tone.neutral => AppColors.chip,
  };

  Color get soft => switch (this) {
    Tone.green => AppColors.successSoft,
    Tone.violet => AppColors.violetSoft,
    Tone.dark => AppColors.chip,
    Tone.red => AppColors.redSoft,
    Tone.amber => AppColors.amberSoft,
    Tone.neutral => AppColors.surfaceAlt,
  };

  Color get onSolid => this == Tone.neutral ? AppColors.ink2 : Colors.white;

  Color get ink => switch (this) {
    Tone.green => AppColors.successDeep,
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
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      secondary: AppColors.success,
      surface: AppColors.surface,
      error: AppColors.red,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    platform: TargetPlatform.iOS,
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: AppColors.blue,
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
      cursorColor: AppColors.blue,
      selectionHandleColor: AppColors.blue,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
