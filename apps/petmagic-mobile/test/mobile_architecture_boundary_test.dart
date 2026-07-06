import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature presentation files do not perform direct HTTP calls', () {
    final violations = <String>[];

    for (final file in _presentationFiles()) {
      final source = file.readAsStringSync();
      for (final rule in _forbiddenPresentationNetworkRules) {
        if (rule.pattern.hasMatch(source)) {
          violations.add('${file.path}: ${rule.reason}');
        }
      }
    }

    expect(violations, isEmpty);
  });
}

Iterable<File> _presentationFiles() {
  final featuresRoot = Directory('lib/features');
  return featuresRoot.listSync(recursive: true).whereType<File>().where((file) {
    final normalizedPath = file.path.replaceAll('\\', '/');
    return normalizedPath.endsWith('.dart') &&
        normalizedPath.contains('/presentation/');
  });
}

final _forbiddenPresentationNetworkRules = [
  _ForbiddenRule(
    RegExp(r'\bdioProvider\b'),
    'presentation must not read the shared Dio provider directly',
  ),
  _ForbiddenRule(
    RegExp(r'\bDio\s*\('),
    'presentation must not construct Dio clients',
  ),
  _ForbiddenRule(
    RegExp(r'\bHttpClient\s*\('),
    'presentation must not construct dart:io HTTP clients',
  ),
  _ForbiddenRule(
    RegExp(r'\b_dio\s*\.'),
    'presentation must not call repository/data-source Dio fields',
  ),
  _ForbiddenRule(
    RegExp(r'\bhttp\.(?:get|post|put|delete|patch|head)\s*\('),
    'presentation must not call package:http directly',
  ),
];

class _ForbiddenRule {
  const _ForbiddenRule(this.pattern, this.reason);

  final RegExp pattern;
  final String reason;
}
