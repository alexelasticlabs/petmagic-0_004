import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pet media URLs retain the configured local backend endpoint', () {
    final source = File(
      'lib/features/pets/presentation/pet_media_url_normalizer.dart',
    ).readAsStringSync();

    expect(source, contains('final baseUri = _petMediaBaseUri();'));
    expect(
      source,
      isNot(contains('_petMediaBaseUri(preferReachableLocalhost: true)')),
    );
  });
}
