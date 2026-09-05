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

  testWidgets('keeps the resolved image while a replacement URL loads', (
    tester,
  ) async {
    final oldLoad = Completer<File>();
    final newLoad = Completer<File>();

    Future<File> load(String imageUrl, {int? mediaVersion}) {
      return imageUrl.endsWith('old.jpg') ? oldLoad.future : newLoad.future;
    }

    Future<void> pumpUrl(String imageUrl) {
      return tester.pumpWidget(
        MaterialApp(
          home: TemplatePreviewImage(
            key: const ValueKey('preserved-preview'),
            imageUrl: imageUrl,
            fileLoader: load,
            preserveOldImageOnUrlChange: true,
            placeholder: const SizedBox(key: ValueKey('preview-placeholder')),
            errorBuilder: (_) => const SizedBox(key: ValueKey('preview-error')),
          ),
        ),
      );
    }

    await pumpUrl('https://cdn.petmagic.test/old.jpg');
    oldLoad.complete(File('assets/icons/app_icon.png'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    await pumpUrl('https://cdn.petmagic.test/new.jpg');
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-placeholder')), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, 'assets/icons/app_icon.png');

    newLoad.complete(File('assets/auth/petmagic-auth-hero.png'));
    await tester.pumpAndSettle();
  });

  testWidgets('routes preserved file decode cleanup to its origin URL', (
    tester,
  ) async {
    final oldLoad = Completer<File>();
    final newLoad = Completer<File>();
    final removals = <({String imageUrl, int? mediaVersion})>[];

    Future<File> load(String imageUrl, {int? mediaVersion}) {
      return imageUrl.endsWith('old.jpg') ? oldLoad.future : newLoad.future;
    }

    Future<void> remove(String imageUrl, {int? mediaVersion}) async {
      removals.add((imageUrl: imageUrl, mediaVersion: mediaVersion));
    }

    Future<void> pumpUrl(String imageUrl, int mediaVersion) {
      return tester.pumpWidget(
        MaterialApp(
          home: TemplatePreviewImage(
            key: const ValueKey('preserved-error-preview'),
            imageUrl: imageUrl,
            mediaVersion: mediaVersion,
            fileLoader: load,
            fileRemover: remove,
            preserveOldImageOnUrlChange: true,
            placeholder: const SizedBox(),
            errorBuilder: (_) =>
                const SizedBox(key: ValueKey('preview-decode-error')),
          ),
        ),
      );
    }

    await pumpUrl('https://cdn.petmagic.test/old.jpg', 3);
    oldLoad.complete(File('assets/icons/app_icon.png'));
    await tester.idle();
    await pumpUrl('https://cdn.petmagic.test/new.jpg', 4);
    final image = tester.widget<Image>(find.byType(Image));
    image.errorBuilder!(
      tester.element(find.byType(Image)),
      StateError('simulated stale file decode failure'),
      StackTrace.current,
    );

    expect(removals, [
      (imageUrl: 'https://cdn.petmagic.test/old.jpg', mediaVersion: 3),
    ]);
  });

  testWidgets('removes image fade when reduced motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: TemplatePreviewImage(
            imageUrl: 'https://cdn.petmagic.test/preview.jpg',
            fileLoader: (imageUrl, {mediaVersion}) async =>
                File('assets/icons/app_icon.png'),
            placeholder: const SizedBox(),
            errorBuilder: (_) => const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.duration, Duration.zero);
  });
}
