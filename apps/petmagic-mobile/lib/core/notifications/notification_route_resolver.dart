/// Converts untrusted notification payloads into allowlisted internal routes.
/// External URLs, query strings, fragments and unsafe generation ids are
/// rejected before the app navigator receives them.
final class NotificationRouteResolver {
  const NotificationRouteResolver();

  static const _allowedNotificationRoutes = <String>{
    '/templates',
    '/creations',
    '/rewards',
    '/profile',
    '/profile/support',
    '/profile/support/chat',
    '/profile/wallet',
    '/profile/premium',
    '/profile/subscription/manage',
  };
  static final RegExp _routeControlCharacters = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _safeGenerationId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  String? routeFromMap(Map<String, dynamic> payload) {
    final route = payload['route'];
    if (route is String) {
      final safeRoute = safeInternalRoute(route);
      if (safeRoute != null) {
        return safeRoute;
      }
    }

    final generationRoute = generationRouteFor(payload['generationId']);
    if (generationRoute != null) {
      return generationRoute;
    }

    final type = payload['type'];
    if (type == 'support_chat') {
      return '/profile/support';
    }
    if (type == 'wallet') {
      return '/profile/wallet';
    }
    if (type == 'premium') {
      return '/profile';
    }

    final conversationId = payload['conversationId'];
    if (conversationId is String && conversationId.isNotEmpty) {
      return '/profile/support';
    }
    return null;
  }

  String? safeInternalRoute(String raw) {
    final value = raw.trim();
    if (value.isEmpty ||
        value.length > 160 ||
        _routeControlCharacters.hasMatch(value) ||
        !value.startsWith('/') ||
        value.startsWith('//') ||
        value.contains(r'\') ||
        value.contains('%')) {
      return null;
    }

    // Uri normalizes dot-segments before exposing path. Reject them from the
    // raw value so `/generations/../profile` cannot become an allowlisted
    // `/profile` destination.
    final rawPathSegments = value.split('/');
    if (rawPathSegments.any((segment) => segment == '.' || segment == '..')) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.fragment.isNotEmpty ||
        uri.query.isNotEmpty) {
      return null;
    }

    final path = uri.path;
    if (_allowedNotificationRoutes.contains(path)) {
      return path;
    }
    if (path.startsWith('/generations/')) {
      final generationId = path.substring('/generations/'.length);
      if (_safeGenerationId.hasMatch(generationId)) {
        return path;
      }
    }
    return null;
  }

  String? generationRouteFor(Object? rawGenerationId) {
    if (rawGenerationId is! String) {
      return null;
    }
    final generationId = rawGenerationId.trim();
    if (!_safeGenerationId.hasMatch(generationId)) {
      return null;
    }
    return '/generations/$generationId';
  }
}
