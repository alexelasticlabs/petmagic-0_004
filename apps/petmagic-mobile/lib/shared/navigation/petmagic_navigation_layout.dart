import 'package:flutter/widgets.dart';

const _bottomNavHeight = 42.0;
const _bottomNavOuterGap = 10.0;
const _bottomNavContentInsetExtra = 18.0;
const _bottomSheetBottomGap = 14.0;

const kPetMagicBottomContentInsetRelaxed = _bottomNavContentInsetExtra;
const kPetMagicBottomContentInsetCompact = _bottomNavOuterGap;

double petMagicBottomNavInset(
  BuildContext context, {
  double extraSpacing = kPetMagicBottomContentInsetRelaxed,
}) {
  final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
  return bottomPadding + _bottomNavHeight + _bottomNavOuterGap + extraSpacing;
}

double petMagicScrollableBottomInset(
  BuildContext context, {
  double extraSpacing = kPetMagicBottomContentInsetRelaxed,
}) => petMagicBottomNavInset(context, extraSpacing: extraSpacing);

double petMagicBottomSheetOffset(BuildContext context) {
  final viewMediaQuery = MediaQueryData.fromView(View.of(context));
  final keyboardInset = viewMediaQuery.viewInsets.bottom;
  if (keyboardInset > 0) return keyboardInset + _bottomSheetBottomGap;

  return viewMediaQuery.viewPadding.bottom +
      _bottomNavHeight +
      _bottomNavOuterGap +
      _bottomSheetBottomGap;
}

class PetMagicShellScope extends InheritedWidget {
  const PetMagicShellScope({required super.child, super.key});

  static bool isPresent(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PetMagicShellScope>() != null;

  @override
  bool updateShouldNotify(PetMagicShellScope oldWidget) => false;
}
