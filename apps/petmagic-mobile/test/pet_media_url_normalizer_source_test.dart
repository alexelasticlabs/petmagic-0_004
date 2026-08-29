import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/pets/application/pets_contract.dart';

void main() {
  test('pet media URLs retain the configured local backend endpoint', () {
    final source = File(
      'lib/features/pets/application/pet_media_url_normalizer.dart',
    ).readAsStringSync();

    expect(source, contains('final baseUri = _petMediaBaseUri();'));
    expect(
      source,
      isNot(contains('_petMediaBaseUri(preferReachableLocalhost: true)')),
    );
  });

  test('pet media URLs preserve existing R2 signature encoding', () {
    const signedUrl =
        'https://example-account.r2.cloudflarestorage.com/petmagic/'
        'templates-media/avatar.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&'
        'X-Amz-Credential=access-key%2F20260829%2Fauto%2Fs3%2Faws4_request&'
        'X-Amz-Date=20260829T002652Z&X-Amz-Expires=900&'
        'X-Amz-SignedHeaders=host&X-Amz-Signature=0123456789abcdef';

    expect(normalizePetMediaUrl(signedUrl), signedUrl);
  });

  test('pet media URLs still encode unsafe path characters', () {
    expect(
      normalizePetMediaUrl(
        'https://cdn.petgpt.app/templates-media/pet photo.jpg',
      ),
      'https://cdn.petgpt.app/templates-media/pet%20photo.jpg',
    );
  });
}
