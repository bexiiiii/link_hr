import 'package:flutter/widgets.dart';

/// One icon set for the whole app: Phosphor fonts bundled in assets/fonts
/// (regular for idle, fill for active). Bundled directly because the
/// phosphor_flutter package no longer compiles on current Flutter.
/// Names follow what screens mean, so swapping the set later is a one-file change.
abstract final class AppIcons {
  static const IconData add = IconData(0xe3d4, fontFamily: 'PhosphorRegular');
  static const IconData addCircledSolid = IconData(
    0xe3d6,
    fontFamily: 'PhosphorFill',
  );
  static const IconData airplane = IconData(
    0xe5d6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData alarm = IconData(0xe006, fontFamily: 'PhosphorRegular');
  static const IconData alarmFill = IconData(
    0xe006,
    fontFamily: 'PhosphorFill',
  );
  static const IconData archivebox = IconData(
    0xe00c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowDownDoc = IconData(
    0xe232,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowDownLeft = IconData(
    0xe040,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowDownLeftSquare = IconData(
    0xe428,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowLeft = IconData(
    0xe058,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowRight = IconData(
    0xe06c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowUp = IconData(
    0xe08e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowUpRight = IconData(
    0xe092,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowUpRightSquare = IconData(
    0xe42a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData bell = IconData(0xe0ce, fontFamily: 'PhosphorRegular');
  static const IconData boltFill = IconData(0xe2de, fontFamily: 'PhosphorFill');
  static const IconData building2Fill = IconData(
    0xe102,
    fontFamily: 'PhosphorFill',
  );
  static const IconData calendar = IconData(
    0xe10a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData camera = IconData(
    0xe10e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData cameraCircle = IconData(
    0xe10e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chartBar = IconData(
    0xe150,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chartBarAltFill = IconData(
    0xe150,
    fontFamily: 'PhosphorFill',
  );
  static const IconData chartPie = IconData(
    0xe15a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData checkmark = IconData(
    0xe182,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData checkmarkAlt = IconData(
    0xe182,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData checkmarkCircle = IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData checkmarkCircleFill = IconData(
    0xe184,
    fontFamily: 'PhosphorFill',
  );
  static const IconData checkmarkSeal = IconData(
    0xe606,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData checkmarkSealFill = IconData(
    0xe606,
    fontFamily: 'PhosphorFill',
  );
  static const IconData checkmarkSquare = IconData(
    0xe186,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chevronDown = IconData(
    0xe136,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chevronLeft = IconData(
    0xe138,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chevronRight = IconData(
    0xe13a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData circle = IconData(
    0xe18a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData circleFill = IconData(
    0xe18a,
    fontFamily: 'PhosphorFill',
  );
  static const IconData clock = IconData(0xe19a, fontFamily: 'PhosphorRegular');
  static const IconData clockFill = IconData(
    0xe19a,
    fontFamily: 'PhosphorFill',
  );
  static const IconData cloudUpload = IconData(
    0xe1ae,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData cloudUploadFill = IconData(
    0xe1ae,
    fontFamily: 'PhosphorFill',
  );
  static const IconData creditcard = IconData(
    0xe1d2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData docCheckmark = IconData(
    0xe188,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData docOnClipboard = IconData(
    0xe198,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData docPlaintext = IconData(
    0xe0a8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData docText = IconData(
    0xe23a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData docTextFill = IconData(
    0xe23a,
    fontFamily: 'PhosphorFill',
  );
  static const IconData docTextSearch = IconData(
    0xe238,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData ellipsis = IconData(
    0xe1fe,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData exclamationmarkCircle = IconData(
    0xe4e2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData exclamationmarkCircleFill = IconData(
    0xe4e2,
    fontFamily: 'PhosphorFill',
  );
  static const IconData exclamationmarkTriangleFill = IconData(
    0xe4e0,
    fontFamily: 'PhosphorFill',
  );
  static const IconData eye = IconData(0xe220, fontFamily: 'PhosphorRegular');
  static const IconData eyeSlash = IconData(
    0xe224,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData flagFill = IconData(0xe244, fontFamily: 'PhosphorFill');
  static const IconData folder = IconData(
    0xe25a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData folderFill = IconData(
    0xe25a,
    fontFamily: 'PhosphorFill',
  );
  static const IconData gear = IconData(0xe272, fontFamily: 'PhosphorRegular');
  static const IconData gearSolid = IconData(
    0xe272,
    fontFamily: 'PhosphorFill',
  );
  static const IconData gift = IconData(0xe276, fontFamily: 'PhosphorRegular');
  static const IconData handPointRight = IconData(
    0xe23e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData handRaised = IconData(
    0xe42a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData house = IconData(0xe2c2, fontFamily: 'PhosphorRegular');
  static const IconData houseFill = IconData(
    0xe2c2,
    fontFamily: 'PhosphorFill',
  );
  static const IconData link = IconData(0xe2e2, fontFamily: 'PhosphorRegular');
  static const IconData listBullet = IconData(
    0xe2f2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData listBulletIndent = IconData(
    0xeadc,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData location = IconData(
    0xe316,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData locationSolid = IconData(
    0xe316,
    fontFamily: 'PhosphorFill',
  );
  static const IconData lock = IconData(0xe2fa, fontFamily: 'PhosphorRegular');
  static const IconData lockOpen = IconData(
    0xe306,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData mic = IconData(0xe326, fontFamily: 'PhosphorRegular');
  static const IconData micFill = IconData(0xe326, fontFamily: 'PhosphorFill');
  static const IconData moneyDollarCircle = IconData(
    0xe68a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData paperclip = IconData(
    0xe39a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData pauseFill = IconData(
    0xe39e,
    fontFamily: 'PhosphorFill',
  );
  static const IconData pencil = IconData(
    0xe3b4,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData person = IconData(
    0xe4c2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData person2 = IconData(
    0xe4d6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData person3 = IconData(
    0xe68e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData personCropCircleBadgeExclam = IconData(
    0xe4ce,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData phone = IconData(0xe3b8, fontFamily: 'PhosphorRegular');
  static const IconData photo = IconData(0xe2ca, fontFamily: 'PhosphorRegular');
  static const IconData playFill = IconData(0xe3d0, fontFamily: 'PhosphorFill');
  static const IconData plus = IconData(0xe3d4, fontFamily: 'PhosphorRegular');
  static const IconData rosette = IconData(
    0xe320,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData search = IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData share = IconData(0xeaf0, fontFamily: 'PhosphorRegular');
  static const IconData signature = IconData(
    0xebac,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData speaker2 = IconData(
    0xe324,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData speaker2Fill = IconData(
    0xe324,
    fontFamily: 'PhosphorFill',
  );
  static const IconData squareArrowLeft = IconData(
    0xe42a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData squareArrowRight = IconData(
    0xe428,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData squareList = IconData(
    0xeadc,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData squareListFill = IconData(
    0xeadc,
    fontFamily: 'PhosphorFill',
  );
  static const IconData squarePencil = IconData(
    0xe34c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData squareSplit2x2Fill = IconData(
    0xeb54,
    fontFamily: 'PhosphorFill',
  );
  static const IconData star = IconData(0xe46a, fontFamily: 'PhosphorRegular');
  static const IconData starFill = IconData(0xe46a, fontFamily: 'PhosphorFill');
  static const IconData stopFill = IconData(0xe46c, fontFamily: 'PhosphorFill');
  static const IconData sunMax = IconData(
    0xe472,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sunriseFill = IconData(
    0xe5b6,
    fontFamily: 'PhosphorFill',
  );
  static const IconData table = IconData(0xe476, fontFamily: 'PhosphorRegular');
  static const IconData textBubble = IconData(
    0xe17a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData timer = IconData(0xe492, fontFamily: 'PhosphorRegular');
  static const IconData trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular');
  static const IconData trayArrowUp = IconData(
    0xee52,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData viewfinder = IconData(
    0xebb6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData wifiExclamationmark = IconData(
    0xe4f2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData xmark = IconData(0xe4f6, fontFamily: 'PhosphorRegular');
  static const IconData xmarkCircle = IconData(
    0xe4f8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData xmarkCircleFill = IconData(
    0xe4f8,
    fontFamily: 'PhosphorFill',
  );
}
