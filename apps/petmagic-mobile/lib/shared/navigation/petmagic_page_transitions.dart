import 'package:flutter/material.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';

Widget petMagicFadeSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (PetMotion.reduceMotion(context)) {
    return FadeTransition(opacity: animation, child: child);
  }

  final curved = CurvedAnimation(
    parent: animation,
    curve: PetMotion.emphasized,
    reverseCurve: Curves.easeInCubic,
  );
  final offset = Tween<Offset>(
    begin: const Offset(0, 0.025),
    end: Offset.zero,
  ).animate(curved);

  return FadeTransition(
    opacity: curved,
    child: SlideTransition(position: offset, child: child),
  );
}

Widget petMagicHorizontalRevealTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final mediaQuery = MediaQuery.maybeOf(context);
  final reduceMotion =
      mediaQuery?.disableAnimations == true ||
      mediaQuery?.accessibleNavigation == true;
  if (reduceMotion) {
    return FadeTransition(opacity: animation, child: child);
  }

  final curved = CurvedAnimation(
    parent: animation,
    curve: PetMotion.emphasized,
    reverseCurve: Curves.easeInCubic,
  );
  final offset = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(curved);

  return SlideTransition(position: offset, child: child);
}

class PetMagicPageTransitionsBuilder extends PageTransitionsBuilder {
  const PetMagicPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return petMagicFadeSlideTransition(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
