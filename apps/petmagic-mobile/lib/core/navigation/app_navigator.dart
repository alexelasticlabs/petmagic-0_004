import 'package:flutter/widgets.dart';

part 'app_destinations.part.dart';
part 'app_template_destinations.part.dart';

/// Typed application destinations used by orchestration code.
///
/// Feature UI stays independent from GoRouter; only the app composition root
/// turns an [AppDestination] into a concrete navigation operation.
sealed class AppDestination {
  const AppDestination();

  String get location;

  Object? get extra => null;
}

abstract interface class AppNavigator {
  void go(AppDestination destination);
  Future<T?> push<T>(AppDestination destination);
  void replace(AppDestination destination);
  bool canPop();
  void pop<T extends Object?>([T? result]);
}

class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    required this.navigator,
    required super.child,
    super.key,
  });

  final AppNavigator navigator;

  static AppNavigator of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppNavigationScope is missing above this context.');
    return scope!.navigator;
  }

  static AppNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigationScope>();

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) =>
      !identical(navigator, oldWidget.navigator);
}
