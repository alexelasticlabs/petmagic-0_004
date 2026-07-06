import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery store provider cancels active downloads on dispose', () {
    final source = File(
      'lib/features/templates/data/generation_gallery_store.dart',
    ).readAsStringSync();

    expect(source, contains("import 'dart:async';"));
    expect(source, contains('final store = GenerationGalleryStore('));
    expect(source, contains('ref.onDispose(() {'));
    expect(source, contains('unawaited(store.cancelActiveDownloads());'));
    expect(source, contains('return store;'));
  });
}
