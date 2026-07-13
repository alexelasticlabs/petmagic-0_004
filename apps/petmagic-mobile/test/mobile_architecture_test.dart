import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core has no dependency on feature layers', () {
    final violations = <String>[];
    for (final entity in Directory('lib/core').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = entity.readAsStringSync();
      if (source.contains('package:petmagic_mobile/features/')) {
        violations.add(entity.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'core must stay independent from feature code.',
    );
  });

  test('shared has no dependency on feature layers', () {
    final violations = <String>[];
    for (final entity in Directory('lib/shared').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('package:petmagic_mobile/features/')) {
        violations.add(entity.path);
      }
    }
    expect(violations, isEmpty);
  });

  test('feature modules consume only public application or domain APIs', () {
    final violations = <String>[];
    final featureImport = RegExp(
      r'package:petmagic_mobile/features/([^/]+)/([^/]+)/',
    );
    final featureRoot = Directory('lib/features');

    for (final entity in featureRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relativePath = entity.path
          .substring(featureRoot.path.length + 1)
          .replaceAll('\\', '/');
      final sourceFeature = relativePath.split('/').first;

      for (final match in featureImport.allMatches(entity.readAsStringSync())) {
        final targetFeature = match.group(1)!;
        final targetLayer = match.group(2)!;
        if (targetFeature == sourceFeature) continue;
        if (targetLayer == 'application' || targetLayer == 'domain') continue;

        violations.add('$relativePath -> $targetFeature/$targetLayer');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Cross-feature dependencies must use an explicit application/domain contract.',
    );
  });

  test('shared settings UI is not owned by the profile feature', () {
    expect(
      File(
        'lib/features/profile/presentation/widgets/profile_settings_bottom_sheets.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File('lib/shared/settings/app_settings_bottom_sheets.dart').existsSync(),
      isTrue,
    );
  });

  test('production code depends on AuthSessionStore contract', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.endsWith('/core/auth/auth_session_storage.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (RegExp(r'\bAuthSessionStorage\s+[a-zA-Z_]').hasMatch(source) ||
          source.contains('AuthSessionStorage()')) {
        violations.add(entity.path);
      }
    }
    expect(violations, isEmpty);
  });

  test(
    'app composition root owns session and push lifecycle orchestration',
    () {
      expect(
        File('lib/core/startup/session_scope_reset.dart').existsSync(),
        isFalse,
      );
      expect(
        File(
          'lib/core/notifications/notification_coordinator.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          'lib/core/notifications/push_notifications_bootstrap.dart',
        ).existsSync(),
        isFalse,
      );
      expect(
        File('lib/core/notifications/push_token_registrar.dart').existsSync(),
        isFalse,
      );

      expect(
        File('lib/app/session/session_scope_reset.dart').existsSync(),
        isTrue,
      );
      expect(
        File(
          'lib/app/notifications/notification_coordinator.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'lib/app/notifications/push_notifications_bootstrap.dart',
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('push and deep links use the typed application navigator', () {
    final navigator = File(
      'lib/core/navigation/app_navigator.dart',
    ).readAsStringSync();
    final bootstrap = File(
      'lib/app/notifications/push_notifications_bootstrap.dart',
    ).readAsStringSync();

    expect(navigator, contains('sealed class AppDestination'));
    expect(navigator, contains('abstract interface class AppNavigator'));
    expect(navigator, contains('final class GenerationDestination'));
    expect(navigator, contains('final class LegalAcceptanceDestination'));
    expect(navigator, contains('final class PetsDestination'));
    expect(navigator, contains('final class SupportChatDestination'));
    expect(bootstrap, contains('final AppNavigator navigator;'));
    expect(bootstrap, contains('widget.navigator.go(destination);'));
    expect(bootstrap, isNot(contains('widget.router.go(')));
    expect(
      File('lib/app/router/go_router_app_navigator.dart').readAsStringSync(),
      contains('final class GoRouterAppNavigator implements AppNavigator'),
    );
  });

  group('Clean Architecture dependency rules', () {
    test('application does not depend on data, presentation, or app', () {
      _expectLayerWithoutDependencies('application', const {
        'data',
        'presentation',
        'app',
      });
    });

    test('presentation does not depend on data implementations', () {
      _expectLayerWithoutDependencies('presentation', const {'data'});
    });

    test('data does not depend on presentation or app composition', () {
      _expectLayerWithoutDependencies('data', const {'presentation', 'app'});
    });

    test('domain stays framework and plugin independent', () {
      final forbiddenImports = <String>[
        'package:flutter/',
        'package:flutter_',
        'package:dio/',
        'package:go_router/',
        'package:firebase_',
        'package:shared_preferences/',
        'package:in_app_purchase/',
        'package:petmagic_mobile/app/',
        'package:petmagic_mobile/shared/',
      ];
      final violations = <String>[];
      for (final file in _featureLayerFiles('domain')) {
        final source = file.readAsStringSync();
        for (final dependency in forbiddenImports) {
          if (source.contains(dependency)) {
            violations.add('${_relative(file)} -> $dependency');
          }
        }
      }
      expect(violations, isEmpty);
    });

    test('application contracts never export implementation layers', () {
      final violations = <String>[];
      for (final file in _featureLayerFiles('application')) {
        final source = file.readAsStringSync();
        if (RegExp(
          r'''export\s+['"][^'"]*/(?:data|presentation)/''',
        ).hasMatch(source)) {
          violations.add(_relative(file));
        }
      }
      expect(violations, isEmpty);
    });

    test('application platform dependency debt is explicit and frozen', () {
      const forbiddenImports = <String>[
        'dart:io',
        'package:cached_network_image/',
        'package:dio/',
        'package:flutter/',
        'package:in_app_purchase/',
        'package:image_picker/',
      ];
      final violations = <String>[];
      final observedDebt = <String>{};
      for (final file in _featureLayerFiles('application')) {
        final path = _relative(file);
        final source = file.readAsStringSync();
        final dependencies = forbiddenImports
            .where(source.contains)
            .toList(growable: false);
        if (dependencies.isEmpty) continue;
        observedDebt.add(path);
        if (!_legacyApplicationPlatformDependencyFiles.contains(path)) {
          violations.add('$path -> ${dependencies.join(', ')}');
        }
      }
      expect(violations, isEmpty);
      expect(
        observedDebt,
        _legacyApplicationPlatformDependencyFiles,
        reason: 'Remove stale debt entries as application ports become pure.',
      );
    });

    test('domain serialization debt is explicit and frozen', () {
      final observedDebt = <String>{};
      for (final file in _featureLayerFiles('domain')) {
        final source = file.readAsStringSync();
        if (source.contains('fromJson') ||
            source.contains('toJson') ||
            source.contains('Map<String, dynamic>')) {
          observedDebt.add(_relative(file));
        }
      }
      expect(
        observedDebt,
        _legacyDomainSerializationFiles,
        reason: 'Wire serialization belongs to data DTO mappers.',
      );
    });

    test('feature and shared UI do not import GoRouter', () {
      final violations = <String>[];
      for (final root in [Directory('lib/features'), Directory('lib/shared')]) {
        for (final file in _dartFiles(root)) {
          if (file.readAsStringSync().contains('package:go_router/')) {
            violations.add(_relative(file));
          }
        }
      }
      expect(violations, isEmpty);
    });

    test('features do not depend on app infrastructure wiring', () {
      const forbidden = [
        'package:petmagic_mobile/app/composition/',
        'package:petmagic_mobile/app/notifications/',
        'package:petmagic_mobile/app/router/',
        'package:petmagic_mobile/app/session/',
        'package:petmagic_mobile/app/shell/',
      ];
      final violations = <String>[];
      for (final file in _dartFiles(Directory('lib/features'))) {
        final source = file.readAsStringSync();
        for (final dependency in forbidden) {
          if (source.contains(dependency)) {
            violations.add('${_relative(file)} -> $dependency');
          }
        }
      }
      expect(violations, isEmpty);
    });
  });

  test('production Dart files stay below the 600 line ownership limit', () {
    final violations = <String>[];
    for (final file in _dartFiles(Directory('lib'))) {
      final path = _relative(file);
      if (path.startsWith('lib/app/localization/generated/') ||
          _legacyOversizedProductionFiles.contains(path)) {
        continue;
      }
      final lineCount = file.readAsLinesSync().length;
      if (lineCount > 600) {
        violations.add('$path ($lineCount lines)');
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Split orchestration and UI by responsibility before it grows.',
    );
  });

  test('production layers keep their target ownership limits', () {
    final observedDebt = <String>{};
    for (final file in _dartFiles(Directory('lib'))) {
      final path = _relative(file);
      if (path.startsWith('lib/app/localization/generated/') ||
          _legacyOversizedProductionFiles.contains(path)) {
        continue;
      }
      if (file.readAsLinesSync().length > _ownershipLimitFor(path)) {
        observedDebt.add(path);
      }
    }
    expect(
      observedDebt,
      _legacyLayerLimitProductionFiles,
      reason:
          'Core/application/data/domain target 400 lines; presentation/shared UI target 500.',
    );
  });

  test('app composition binds every external feature port', () {
    final composition = File(
      'lib/app/composition/mobile_provider_overrides.dart',
    ).readAsStringSync();
    for (final provider in const [
      'appRuntimeInfoProvider',
      'templatesRepositoryProvider',
      'petRepositoryProvider',
      'gamificationRepositoryProvider',
      'supportChatRepositoryProvider',
      'supportChatRealtimeClientProvider',
      'externalAuthRepositoryProvider',
      'profileRepositoryProvider',
      'avatarMediaGatewayProvider',
      'pushTokenLifecyclePortProvider',
      'notificationPreferencesStorageProvider',
      'walletRepositoryProvider',
      'premiumRepositoryProvider',
      'templateGenerationRepositoryProvider',
      'generationGalleryStoreProvider',
    ]) {
      expect(composition, contains('$provider.overrideWith'));
    }
  });
}

Iterable<File> _dartFiles(Directory root) sync* {
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

Iterable<File> _featureLayerFiles(String layer) => _dartFiles(
  Directory('lib/features'),
).where((file) => _relative(file).contains('/$layer/'));

void _expectLayerWithoutDependencies(
  String sourceLayer,
  Set<String> forbiddenLayers,
) {
  final violations = <String>[];
  for (final file in _featureLayerFiles(sourceLayer)) {
    final source = file.readAsStringSync();
    for (final targetLayer in forbiddenLayers) {
      final packageDependency = targetLayer == 'app'
          ? 'package:petmagic_mobile/app/'
          : '/$targetLayer/';
      if (source.contains(packageDependency) ||
          source.contains('../$targetLayer/')) {
        violations.add('${_relative(file)} -> $targetLayer');
      }
    }
  }
  expect(violations, isEmpty);
}

String _relative(File file) => file.path.replaceAll('\\', '/');

int _ownershipLimitFor(String path) {
  final isPresentation =
      path.contains('/presentation/') ||
      path.startsWith('lib/shared/') ||
      path.startsWith('lib/app/theme/');
  return isPresentation ? 500 : 400;
}

// Existing ownership debt is explicit and frozen: no new oversized file can
// enter the codebase, while each split removes one entry from this list.
const _legacyOversizedProductionFiles = <String>{
  'lib/features/pets/presentation/my_pets_display_widgets.part.dart',
  'lib/features/pets/presentation/my_pets_form_sheet.part.dart',
  'lib/features/premium/application/premium_controller_checkout.part.dart',
  'lib/features/premium/presentation/premium_page.dart',
  'lib/features/premium/presentation/subscription_management_sections.part.dart',
  'lib/features/profile/application/profile_controller.dart',
  'lib/features/profile/data/external_auth_repository.dart',
  'lib/features/profile/data/profile_repository.dart',
  'lib/features/profile/presentation/profile_settings_detail_page.dart',
  'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
  'lib/features/rewards/presentation/rewards_page_shared_widgets.dart',
  'lib/features/support/presentation/support_chat_controller_conversation.part.dart',
  'lib/features/support/presentation/support_chat_page.dart',
  'lib/features/support/presentation/support_ticket_form_page.dart',
  'lib/features/support/presentation/widgets/support_chat_attachment_picker.part.dart',
  'lib/features/support/presentation/widgets/support_chat_messages.part.dart',
  'lib/features/support/presentation/widgets/support_chat_message_media.part.dart',
  'lib/features/support/presentation/widgets/support_chat_sections_composer.part.dart',
  'lib/features/templates/application/generation_history_controller_sync.part.dart',
  'lib/features/templates/application/templates_controller.dart',
  'lib/features/templates/data/generation_gallery_store_storage.part.dart',
  'lib/features/templates/data/template_generation_repository.dart',
  'lib/features/templates/data/template_generation_repository_cache.part.dart',
  'lib/features/templates/presentation/generations_gallery_page.dart',
  'lib/features/templates/presentation/generations_gallery_page_cards.dart',
  'lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart',
  'lib/features/templates/presentation/generation_result_input_page.dart',
  'lib/features/templates/presentation/generation_status_page.dart',
  'lib/features/templates/presentation/generation_status_page_lifecycle.part.dart',
  'lib/features/templates/presentation/generation_status_page_media_actions.part.dart',
  'lib/features/templates/presentation/generation_status_page_result_sections.part.dart',
  'lib/features/templates/presentation/template_generation_controller.dart',
  'lib/features/templates/presentation/widgets/pet_generation_launch_sheet.dart',
  'lib/features/templates/presentation/widgets/template_card.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_generation.part.dart',
  'lib/features/wallet/application/wallet_controller_checkout.part.dart',
  'lib/features/wallet/presentation/all_transactions_page.dart',
  'lib/features/wallet/presentation/wallet_page.dart',
  'lib/features/wallet/presentation/widgets/wallet_page_overview_chrome.part.dart',
};

// Existing files between their target layer limit and the absolute 600-line
// ceiling. This set is exact: every extraction must remove its stale entry.
const _legacyLayerLimitProductionFiles = <String>{
  'lib/app/notifications/notification_coordinator.dart',
  'lib/app/notifications/push_notifications_bootstrap.dart',
  'lib/app/notifications/push_token_registrar.dart',
  'lib/app/router/app_router.dart',
  'lib/core/navigation/app_navigator.dart',
  'lib/core/performance/template_media_cache.dart',
  'lib/core/realtime/realtime_client.dart',
  'lib/features/premium/application/premium_controller.dart',
  'lib/features/premium/data/premium_repository.dart',
  'lib/features/premium/presentation/premium_page_sections.part.dart',
  'lib/features/profile/presentation/password_change_page.dart',
  'lib/features/profile/presentation/profile_avatar_cropper_page.dart',
  'lib/features/profile/presentation/profile_page.dart',
  'lib/features/profile/presentation/widgets/profile_linked_accounts_settings_section.dart',
  'lib/features/startup/presentation/guest_welcome_content.part.dart',
  'lib/features/support/presentation/support_home_page.dart',
  'lib/features/support/data/support_chat_repository.dart',
  'lib/features/templates/application/generation_history_controller_cache.part.dart',
  'lib/features/templates/application/generation_history_controller_lifecycle.part.dart',
  'lib/features/templates/data/generation_gallery_store_entries.part.dart',
  'lib/features/templates/data/template_generation_dtos.dart',
  'lib/features/templates/data/templates_remote_data_source.dart',
  'lib/features/templates/data/templates_repository.dart',
  'lib/features/templates/domain/template_generation_models.dart',
  'lib/features/templates/presentation/generation_status_page_result_actions.part.dart',
  'lib/features/templates/presentation/generations_gallery_page_filters_and_chrome.dart',
  'lib/features/templates/presentation/template_feed_playback_manager.dart',
  'lib/features/templates/presentation/templates_page.dart',
  'lib/features/templates/presentation/templates_page_feed.part.dart',
  'lib/features/templates/presentation/templates_page_generation_flow.part.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_chrome.part.dart',
  'lib/features/wallet/application/wallet_controller_loading.part.dart',
  'lib/features/wallet/data/wallet_repository.dart',
  'lib/features/wallet/presentation/widgets/wallet_page_activity_widgets.dart',
  'lib/shared/settings/app_settings_bottom_sheets.dart',
  'lib/shared/widgets/petmagic_action_sheet.dart',
};

const _legacyApplicationPlatformDependencyFiles = <String>{};

const _legacyDomainSerializationFiles = <String>{};
