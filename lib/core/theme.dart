import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// High-contrast iOS product language from the September references: neutral
/// surfaces, near-black controls and lime green only for work actions/state.
abstract final class AppColors {
  static const bg = Color(0xFFF4F4F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFECECEA);
  static const line = Color(0xFFE2E2DF);

  static const ink = Color(0xFF171815);
  static const ink2 = Color(0xFF4F514B);
  static const ink3 = Color(0xFF777A72);
  static const ink4 = Color(0xFFAFB1AA);

  /// Legacy `blue` is the product action token used by existing screens.
  static const blue = Color(0xFF67C746);
  static const blueDeep = Color(0xFF4EAA31);
  static const blueSoft = Color(0xFFE8F7E2);
  static const blueGlow = Color(0xFFCDEFC1);

  /// Existing feature actions use these legacy aliases and now inherit orange.
  static const green = blue;
  static const greenDeep = blueDeep;
  static const greenSoft = blueSoft;
  static const greenGlow = blueGlow;

  /// Secondary data series and informational state.
  static const violet = Color(0xFF2D82F3);
  static const violetSoft = Color(0xFFE8F1FE);
  static const purple = Color(0xFF8D63E8);
  static const purpleSoft = Color(0xFFF0EAFE);

  /// Semantic status colours are deliberately independent from primary action.
  static const success = Color(0xFF67C746);
  static const successDeep = Color(0xFF418F2A);
  static const successSoft = Color(0xFFE8F7E2);

  /// Legacy "graphite" name: dark ink for icons and strong text.
  static const charcoal = Color(0xFF242522);

  static const red = Color(0xFFF03A47);
  static const redSoft = Color(0xFFFDE8EA);
  static const amber = Color(0xFFFF7418);
  static const amberSoft = Color(0xFFFFF0E7);
  static const warn = Color(0xFFEAB308);
  static const warnSoft = Color(0xFFFFF8D6);
  static const plum = blue;
  static const plumSoft = blueSoft;

  static const chip = Color(0xFFECECEA);
  static const chipDot = Color(0xFFC8CAC3);
  static const camera = Color(0xFF0C0F0E);
}

const kFont = 'Onest';

abstract final class AppText {
  static const display = TextStyle(
    fontFamily: kFont,
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: AppColors.ink,
  );
  static const title = TextStyle(
    fontFamily: kFont,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );
  static const heading = TextStyle(
    fontFamily: kFont,
    fontSize: 19,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const cardTitle = TextStyle(
    fontFamily: kFont,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontFamily: kFont,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
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
  static const card = 16.0;
  static const tile = 12.0;
  static const field = 12.0;
  static const pill = 999.0;
}

/// The one soft shadow used for cards; the nav pill and clock button use [AppShadow.float].
abstract final class AppShadow {
  static const card = <BoxShadow>[];
  static const float = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3)),
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
