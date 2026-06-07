import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ui initState microtasks guard provider reads after disposal', () {
    final files = {
      'lib/features/premium/presentation/premium_page.dart',
      'lib/features/premium/presentation/stripe_paymentsheet_smoke_test_page.dart',
      'lib/features/profile/presentation/password_reset_page.dart',
      'lib/features/profile/presentation/password_change_page.dart',
      'lib/features/wallet/presentation/wallet_page.dart',
      'lib/features/wallet/presentation/all_transactions_page.dart',
      'lib/features/rewards/presentation/rewards_page.dart',
      'lib/features/support/presentation/support_ticket_form_page.dart',
    };

    for (final path in files) {
      final source = File(path).readAsStringSync();
      final microtasks = _microtaskBodies(source).toList();

      expect(microtasks, isNotEmpty, reason: path);
      for (final body in microtasks) {
        if (!body.contains('ref.read') && !body.contains('_walletController')) {
          continue;
        }

        expect(body, contains('if (!mounted)'), reason: path);
      }
    }
  });

  test('support ticket preload guards lifecycle before provider reads', () {
    final source = File(
      'lib/features/support/presentation/support_ticket_form_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'Future.microtask(() async {\n'
        '        if (!mounted) {\n'
        '          return;\n'
        '        }\n'
        '        await _preloadSupportContext();',
      ),
    );
    expect(
      source,
      contains(
        'Future<void> _preloadSupportContext() async {\n'
        '    if (!mounted) {\n'
        '      return;\n'
        '    }',
      ),
    );
    expect(
      source,
      contains(
        'try {\n'
        '      await load();\n'
        '    } catch (error, stackTrace) {\n'
        '      if (!mounted) {\n'
        '        return;\n'
        '      }',
      ),
    );
  });
}

Iterable<String> _microtaskBodies(String source) sync* {
  var searchFrom = 0;
  while (true) {
    final start = source.indexOf('Future.microtask(()', searchFrom);
    if (start < 0) {
      return;
    }

    final openBrace = source.indexOf('{', start);
    if (openBrace < 0) {
      return;
    }

    var depth = 0;
    for (var index = openBrace; index < source.length; index++) {
      final char = source[index];
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          yield source.substring(openBrace, index + 1);
          searchFrom = index + 1;
          break;
        }
      }

      if (index == source.length - 1) {
        return;
      }
    }
  }
}
