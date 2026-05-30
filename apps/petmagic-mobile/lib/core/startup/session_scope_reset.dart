import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_controller.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_controller.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';

final sessionScopeResetProvider = Provider<void>((ref) {
  ref.listen<AppLaunchState>(appLaunchControllerProvider, (previous, next) {
    final authChanged = previous?.isAuthenticated != next.isAuthenticated;
    if (!authChanged) {
      return;
    }

    ref.invalidate(walletControllerProvider);
    ref.invalidate(templatesControllerProvider);
    ref.invalidate(generationHistoryControllerProvider);
    ref.invalidate(templateGenerationControllerProvider);
    ref.invalidate(premiumControllerProvider);
    ref.invalidate(premiumSubscriptionSummaryProvider);
    ref.invalidate(linkedAccountsProvider);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(supportChatControllerProvider);

    if (!next.isAuthenticated) {
      final templateGenerationRepository = ref.read(
        templateGenerationRepositoryProvider,
      );
      unawaited(
        Future.wait<void>([
          templateGenerationRepository.clearLocalCache(),
          TemplateMediaCache.clearAll(),
        ]),
      );
    }
  });
});
