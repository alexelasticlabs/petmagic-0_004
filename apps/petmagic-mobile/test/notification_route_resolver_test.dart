import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/notifications/notification_route_resolver.dart';

void main() {
  const resolver = NotificationRouteResolver();

  test('allows only known internal notification destinations', () {
    for (final route in const [
      '/templates',
      '/creations',
      '/rewards',
      '/profile',
      '/profile/support',
      '/profile/support/chat',
      '/profile/wallet',
      '/profile/premium',
      '/profile/subscription/manage',
      '/generations/generation_123-ABC',
    ]) {
      expect(resolver.routeFromMap({'route': route}), route);
    }
  });

  test('rejects external, ambiguous and parameterized routes', () {
    for (final route in const [
      'https://example.com/profile',
      '//example.com/profile',
      '/profile?next=https://example.com',
      '/profile#fragment',
      r'/profile\wallet',
      '/unknown',
      '/generations/../profile',
      '/generations/id%2Fprofile',
      '/profile\u0000',
    ]) {
      expect(resolver.routeFromMap({'route': route}), isNull, reason: route);
    }
  });

  test('maps typed payloads without trusting arbitrary route values', () {
    expect(resolver.routeFromMap({'type': 'support_chat'}), '/profile/support');
    expect(resolver.routeFromMap({'type': 'wallet'}), '/profile/wallet');
    expect(resolver.routeFromMap({'type': 'premium'}), '/profile');
    expect(
      resolver.routeFromMap({'generationId': 'safe_generation-id'}),
      '/generations/safe_generation-id',
    );
    expect(resolver.routeFromMap({'generationId': '../unsafe'}), isNull);
  });

  test('safe explicit route wins over typed fallback', () {
    expect(
      resolver.routeFromMap({'route': '/creations', 'type': 'wallet'}),
      '/creations',
    );
  });
}
