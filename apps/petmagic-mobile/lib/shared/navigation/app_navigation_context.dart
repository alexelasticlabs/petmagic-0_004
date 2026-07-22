import 'package:flutter/widgets.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';

/// Resolves the typed application navigator provided by the app composition.
extension AppNavigationContext on BuildContext {
  AppNavigator get appNavigator =>
      AppNavigationScope.maybeOf(this)?.navigator ??
      _NavigatorContextAppNavigator(this);
}

/// Framework-only fallback for isolated widget tests and reusable previews.
/// Production navigation is always supplied by [AppNavigationScope].
final class _NavigatorContextAppNavigator implements AppNavigator {
  const _NavigatorContextAppNavigator(this._context);

  final BuildContext _context;

  NavigatorState get _navigator => Navigator.of(_context);

  @override
  void go(AppDestination destination) {
    _navigator.pushNamedAndRemoveUntil(
      destination.location,
      (route) => false,
      arguments: destination.extra,
    );
  }

  @override
  Future<T?> push<T>(AppDestination destination) => _navigator.pushNamed<T>(
    destination.location,
    arguments: destination.extra,
  );

  @override
  void replace(AppDestination destination) {
    _navigator.pushReplacementNamed(
      destination.location,
      arguments: destination.extra,
    );
  }

  @override
  bool canPop() => _navigator.canPop();

  @override
  void pop<T extends Object?>([T? result]) => _navigator.pop<T>(result);
}
