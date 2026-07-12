import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';

final class GoRouterAppNavigator implements AppNavigator {
  const GoRouterAppNavigator(this._router);

  final GoRouter _router;

  @override
  void go(AppDestination destination) =>
      _router.go(destination.location, extra: destination.extra);

  @override
  Future<T?> push<T>(AppDestination destination) =>
      _router.push<T>(destination.location, extra: destination.extra);

  @override
  void replace(AppDestination destination) =>
      _router.replace(destination.location, extra: destination.extra);

  @override
  bool canPop() => _router.canPop();

  @override
  void pop<T extends Object?>([T? result]) => _router.pop<T>(result);
}
