import 'package:petmagic_mobile/app/notifications/firebase_push_token_lifecycle_adapter.dart';
import 'package:petmagic_mobile/features/gamification/data/gamification_repository.dart';
import 'package:petmagic_mobile/features/premium/data/premium_repository.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/data/notification_preferences_storage.dart';
import 'package:petmagic_mobile/features/profile/application/push_token_lifecycle_port.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_repository.dart';

final mobileProviderOverrides = [
  gamificationRepositoryProvider.overrideWith(
    (ref) => ref.watch(dioGamificationRepositoryProvider),
  ),
  premiumRepositoryProvider.overrideWith(
    (ref) => ref.watch(dioPremiumRepositoryProvider),
  ),
  externalAuthRepositoryProvider.overrideWith(
    (ref) => ref.watch(mobileExternalAuthRepositoryProvider),
  ),
  profileRepositoryProvider.overrideWith(
    (ref) => ref.watch(dioProfileRepositoryProvider),
  ),
  notificationPreferencesStorageProvider.overrideWith(
    (ref) => ref.watch(sharedPreferencesNotificationPreferencesStorageProvider),
  ),
  pushTokenLifecyclePortProvider.overrideWith(
    (ref) => ref.watch(firebasePushTokenLifecycleAdapterProvider),
  ),
  supportChatRepositoryProvider.overrideWith(
    (ref) => ref.watch(dioSupportRepositoryProvider),
  ),
  supportChatRealtimeClientProvider.overrideWith(
    bindSignalRSupportRealtimeGateway,
  ),
  templatesRepositoryProvider.overrideWith(
    (ref) => ref.watch(defaultTemplatesRepositoryProvider),
  ),
  templateGenerationRepositoryProvider.overrideWith(
    (ref) => ref.watch(dioTemplateGenerationRepositoryProvider),
  ),
  generationGalleryStoreProvider.overrideWith(
    (ref) => ref.watch(fileGenerationGalleryStoreProvider),
  ),
  walletRepositoryProvider.overrideWith(
    (ref) => ref.watch(dioWalletRepositoryProvider),
  ),
];
