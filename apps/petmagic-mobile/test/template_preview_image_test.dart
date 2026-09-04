import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';

void main() {
  testWidgets('same URL reloads when mediaVersion changes', (tester) async {
    final calls = <({String imageUrl, int? mediaVersion})>[];
    final pendingLoads = <Completer<File>>[];

    Future<File> load(String imageUrl, {int? mediaVersion}) {
      calls.add((imageUrl: imageUrl, mediaVersion: mediaVersion));
      final completer = Completer<File>();
      pendingLoads.add(completer);
      return completer.future;
    }

    Future<void> pumpVersion(int mediaVersion) {
      return tester.pumpWidget(
        MaterialApp(
          home: TemplatePreviewImage(
            key: const ValueKey('versioned-preview'),
            imageUrl: 'https://cdn.petmagic.test/preview.jpg',
            mediaVersion: mediaVersion,
            fileLoader: load,
            placeholder: const SizedBox(),
            errorBuilder: (_) => const SizedBox(),
          ),
        ),
      );
    }

    await pumpVersion(3);
    await pumpVersion(4);

    expect(calls, [
      (imageUrl: 'https://cdn.petmagic.test/preview.jpg', mediaVersion: 3),
      (imageUrl: 'https://cdn.petmagic.test/preview.jpg', mediaVersion: 4),
    ]);
    expect(pendingLoads, hasLength(2));
  });
}
