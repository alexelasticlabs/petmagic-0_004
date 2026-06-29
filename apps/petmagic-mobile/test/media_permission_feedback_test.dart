import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';

import 'test_permission_fakes.dart';

void main() {
  testWidgets(
    'denied gallery permission maps to warning without settings action',
    (tester) async {
      late AppLocalizations text;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              text = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final feedback =
          MediaPermissionFeedbackCoordinator(
            FakeAppPermissionCoordinator(),
          ).mapStatusFromText(
            text,
            flow: MediaPermissionFlow.galleryPhoto,
            status: const AppPermissionStatus(
              type: AppPermissionType.photos,
              state: AppPermissionState.denied,
            ),
          );

      expect(feedback.granted, isFalse);
      expect(
        feedback.message,
        'Allow access to your gallery to choose a photo.',
      );
      expect(feedback.actionLabel, isNull);
    },
  );

  testWidgets('blocked camera permission maps to settings action feedback', (
    tester,
  ) async {
    late AppLocalizations text;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            text = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final feedback =
        MediaPermissionFeedbackCoordinator(
          FakeAppPermissionCoordinator(),
        ).mapStatusFromText(
          text,
          flow: MediaPermissionFlow.cameraPhoto,
          status: const AppPermissionStatus(
            type: AppPermissionType.camera,
            state: AppPermissionState.permanentlyDenied,
          ),
        );

    expect(feedback.granted, isFalse);
    expect(
      feedback.message,
      'Camera access is off. Open device settings to allow it.',
    );
    expect(feedback.actionLabel, 'Open settings');
    expect(feedback.onAction, isNotNull);
  });

  testWidgets(
    'blocked gallery permission uses localized non-English permission copy',
    (tester) async {
      late AppLocalizations text;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              text = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final feedback =
          MediaPermissionFeedbackCoordinator(
            FakeAppPermissionCoordinator(),
          ).mapStatusFromText(
            text,
            flow: MediaPermissionFlow.galleryPhoto,
            status: const AppPermissionStatus(
              type: AppPermissionType.photos,
              state: AppPermissionState.permanentlyDenied,
            ),
          );

      expect(feedback.granted, isFalse);
      expect(feedback.title, 'Acceso necesario');
      expect(
        feedback.message,
        'El acceso a fotos está bloqueado. Abre los ajustes y permite el acceso de PetMagic.',
      );
      expect(feedback.actionLabel, 'Abrir ajustes');
    },
  );

  testWidgets('limited gallery permission is treated as granted', (
    tester,
  ) async {
    late AppLocalizations text;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            text = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final feedback =
        MediaPermissionFeedbackCoordinator(
          FakeAppPermissionCoordinator(),
        ).mapStatusFromText(
          text,
          flow: MediaPermissionFlow.galleryPhoto,
          status: const AppPermissionStatus(
            type: AppPermissionType.photos,
            state: AppPermissionState.limited,
          ),
        );

    expect(feedback.granted, isTrue);
    expect(feedback.message, isNull);
  });
}
