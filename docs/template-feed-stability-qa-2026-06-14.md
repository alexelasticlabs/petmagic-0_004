# Template Feed Stability QA - 2026-06-14

## Scope

This note tracks verification evidence for the mobile template feed hardening work:

- 1000+ template feed lazy rendering and pagination trigger.
- Backend-backed category/type/search/random template flows.
- Image/video preview caching and lifecycle safety.
- Template media cache bounds and generation gallery cache pruning.
- Device smoke coverage for the 1000+ feed scenario.

## Automated Evidence

### Mobile analyzer and widget/unit tests

Commands that passed:

```sh
flutter analyze
dart analyze integration_test/templates_feed_stress_test.dart test_driver/integration_test.dart
dart analyze integration_test/templates_feed_backend_stress_test.dart
dart analyze integration_test/templates_feed_http_backend_smoke_test.dart
dart analyze test/templates_controller_backend_data_source_test.dart
dart analyze test/templates_page_backend_feed_test.dart
flutter test test/templates_controller_backend_data_source_test.dart
flutter test test/templates_page_backend_feed_test.dart
flutter test test/templates_remote_data_source_test.dart test/templates_controller_test.dart test/templates_page_lifecycle_test.dart test/template_media_performance_test.dart test/template_card_test.dart test/video_preview_lifecycle_test.dart test/template_random_selector_test.dart test/my_pets_page_test.dart
flutter test test/generation_gallery_store_test.dart test/generation_history_controller_test.dart
```

Latest focused rerun on the current worktree:

```sh
dart analyze test/templates_page_backend_feed_test.dart
dart analyze lib/features/templates/presentation/generation_history_controller.dart test/generation_history_controller_test.dart
dart analyze test/generation_history_controller_lifecycle_test.dart lib/features/templates/presentation/generation_history_controller.dart test/generation_history_controller_test.dart
dart analyze test/generation_history_controller_test.dart
dart analyze test/generation_gallery_store_test.dart
dart analyze lib/features/templates/presentation/generations_gallery_page.dart lib/features/templates/presentation/generations_gallery_page_cards.dart lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart test/generations_gallery_page_test.dart
dart analyze lib/features/pets/presentation/my_pets_page.dart test/my_pets_page_test.dart
dart analyze lib/features/templates/data/generation_gallery_store.dart test/generation_gallery_store_test.dart
dart analyze integration_test/gallery_cross_flow_test.dart
dart analyze lib/core/performance/template_media_cache.dart lib/features/templates/presentation/templates_controller.dart lib/features/templates/presentation/widgets/template_card.dart test/template_card_test.dart test/template_media_performance_test.dart integration_test/templates_feed_http_backend_smoke_test.dart
dart analyze test/template_card_test.dart test/template_media_performance_test.dart lib/core/performance/template_media_cache.dart lib/core/performance/template_preview_video_controller.dart lib/features/templates/presentation/widgets/template_card.dart
dart analyze lib/core/performance/template_media_cache.dart test/template_media_performance_test.dart
dart analyze lib/core/config/app_config.dart lib/shared/navigation/external_url_policy.dart test/external_url_policy_test.dart integration_test/templates_feed_http_backend_smoke_test.dart
dart analyze lib/features/pets/presentation/my_pets_page.dart test/my_pets_page_test.dart
dart analyze integration_test/templates_external_backend_smoke_test.dart
dart analyze integration_test/gallery_cross_flow_test.dart test/templates_page_lifecycle_test.dart
dart analyze test/widget_test.dart test/widget_test_support.part.dart lib/app/router/app_router.dart
dart analyze test/generations_gallery_mappers_test.dart lib/features/templates/presentation/mappers/generations_gallery_mappers.dart
flutter test test/templates_page_backend_feed_test.dart
flutter test test/template_media_performance_test.dart test/video_preview_lifecycle_test.dart test/template_card_test.dart
flutter test test/template_media_performance_test.dart
flutter test test/template_media_performance_test.dart
dart analyze test/template_media_performance_test.dart test/video_preview_lifecycle_test.dart test/template_card_test.dart
dart analyze lib/core/performance/template_media_cache.dart lib/core/performance/template_preview_video_controller.dart lib/features/templates/presentation/widgets/template_card.dart test/template_media_performance_test.dart test/template_card_test.dart test/video_preview_lifecycle_test.dart
flutter test test/template_media_performance_test.dart test/template_card_test.dart test/video_preview_lifecycle_test.dart --reporter=compact
dart analyze lib/features/templates/data/templates_repository.dart lib/features/templates/data/templates_remote_data_source.dart lib/features/templates/presentation/templates_controller.dart lib/features/templates/presentation/templates_page.dart lib/features/templates/presentation/widgets/template_card.dart lib/core/performance/template_media_cache.dart lib/core/performance/template_preview_video_controller.dart test/templates_controller_test.dart test/templates_page_lifecycle_test.dart test/templates_page_backend_feed_test.dart test/templates_controller_backend_data_source_test.dart test/templates_remote_data_source_test.dart test/template_media_performance_test.dart test/template_card_test.dart test/video_preview_lifecycle_test.dart test/widget_test_support.part.dart
flutter test test/templates_controller_test.dart test/templates_page_lifecycle_test.dart test/templates_page_backend_feed_test.dart test/templates_controller_backend_data_source_test.dart test/templates_remote_data_source_test.dart test/template_media_performance_test.dart test/template_card_test.dart test/video_preview_lifecycle_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/templates_controller.dart test/templates_controller_test.dart test/templates_remote_data_source_test.dart
flutter test test/templates_controller_test.dart test/templates_remote_data_source_test.dart test/template_random_selector_test.dart test/templates_page_lifecycle_test.dart
dart analyze lib/features/templates/data/templates_repository.dart lib/features/templates/data/templates_remote_data_source.dart lib/features/templates/presentation/templates_controller.dart lib/features/templates/presentation/templates_page.dart test/templates_controller_test.dart test/templates_page_lifecycle_test.dart test/templates_page_backend_feed_test.dart test/templates_controller_backend_data_source_test.dart test/templates_remote_data_source_test.dart test/widget_test_support.part.dart
flutter test test/templates_controller_test.dart test/templates_page_lifecycle_test.dart test/templates_page_backend_feed_test.dart test/templates_controller_backend_data_source_test.dart test/templates_remote_data_source_test.dart
flutter test --no-pub test/templates_controller_test.dart --name "does not update categories after screen hides" --reporter=compact
flutter test --no-pub test/templates_controller_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/templates_page.dart test/templates_page_lifecycle_test.dart
flutter test test/templates_page_lifecycle_test.dart --reporter=compact
flutter test --no-pub test/templates_page_lifecycle_test.dart --name "templates page cancels pending search debounce when hidden" --reporter=compact
flutter test --no-pub test/templates_page_lifecycle_test.dart --name "random template result is ignored after templates tab hides" --reporter=compact
flutter test --no-pub test/templates_remote_data_source_test.dart --name "cancelPendingRandomTemplateRequest cancels active random request" --reporter=compact
flutter test --no-pub test/templates_page_lifecycle_test.dart --name "random template uses backend selection instead of visible list" --reporter=compact
flutter test --no-pub test/templates_page_lifecycle_test.dart --reporter=compact
flutter test --no-pub test/templates_remote_data_source_test.dart --reporter=compact
flutter test --no-pub test/templates_remote_data_source_test.dart test/templates_page_lifecycle_test.dart --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --name "explicit media removal does not cancel unrelated in-flight downloads" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --name "template preview controller does not fall back to network after invalidation" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart test/template_card_test.dart test/video_preview_lifecycle_test.dart --reporter=compact
flutter test test/external_url_policy_test.dart test/production_networking_config_test.dart test/app_config_security_test.dart
flutter test test/my_pets_page_test.dart
flutter test -d emulator-5554 integration_test/templates_external_backend_smoke_test.dart --dart-define=PETMAGIC_SKIP_FIREBASE=true
RUN_ID=android-emulator-template-feed-external-smoke-skip-20260615T021439Z DEVICE_ID=emulator-5554 MODE=debug TARGET=integration_test/templates_external_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
flutter test test/widget_test.dart --name "app router registers pet details creations and generation status routes" --reporter=compact
flutter test test/widget_test.dart test/generations_gallery_page_test.dart test/my_pets_page_test.dart --reporter=compact
flutter test test/generations_gallery_mappers_test.dart --reporter=compact
flutter test test/generations_gallery_mappers_test.dart test/generations_gallery_page_test.dart test/widget_test.dart test/my_pets_page_test.dart --reporter=compact
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~TemplatesServiceTests.Catalog|FullyQualifiedName~TemplatesApiIntegrationTests.Catalog|FullyQualifiedName~AdminTemplateEndpointHardeningTests"
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~DatabaseIndexModelTests"
flutter test test/generation_history_controller_test.dart test/generation_gallery_store_test.dart
flutter test test/generation_history_controller_lifecycle_test.dart test/generation_history_controller_test.dart test/generation_gallery_store_test.dart
flutter test test/generation_gallery_store_test.dart
flutter test test/session_scope_reset_test.dart
flutter test test/generations_gallery_page_test.dart
flutter test test/my_pets_page_test.dart
flutter test -d emulator-5554 integration_test/gallery_cross_flow_test.dart
RUN_ID=android-emulator-gallery-cross-flow-production-safe-profile-20260615T022457Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-gallery-cross-flow-production-safe-gsm-20260615T023728Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/gallery_cross_flow_test.dart NETWORK_SPEED=gsm ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
flutter test -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 integration_test/gallery_cross_flow_test.dart
RUN_ID=ios-simulator-gallery-cross-flow-current-debug-20260615T070421Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-gallery-cross-flow-current-profile-20260615T070619Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-gallery-cross-flow-current-gsm-20260615T070733Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/gallery_cross_flow_test.dart NETWORK_SPEED=gsm ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
dart analyze integration_test/templates_feed_http_backend_smoke_test.dart
dart analyze test/templates_page_backend_feed_test.dart
dart analyze test/templates_page_lifecycle_test.dart
dart analyze lib/features/templates/presentation/widgets/template_card.dart test/template_card_test.dart
dart analyze lib/features/templates/presentation/widgets/template_card.dart test/template_media_performance_test.dart test/template_card_test.dart
flutter test --no-pub test/template_card_test.dart --name "TemplateCard prefers thumbnail over original image preview" --reporter=compact
flutter test --no-pub test/template_card_test.dart --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart test/template_card_test.dart --reporter=compact
dart analyze lib/core/performance/template_media_cache.dart test/template_media_performance_test.dart
flutter test --no-pub test/template_media_performance_test.dart --name "template media caches refresh expired remembered thumbnail and video files" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/templates_page.dart test/template_media_performance_test.dart
flutter test --no-pub test/template_media_performance_test.dart --name "template of the day hero thumbnail is cached at bounded size" --reporter=compact
flutter test --no-pub test/templates_page_lifecycle_test.dart --reporter=compact
dart analyze lib/core/config/app_config.dart lib/core/performance/decoded_image_cache_budget.dart lib/main.dart test/app_config_media_defaults_test.dart test/decoded_image_cache_budget_test.dart test/template_media_performance_test.dart
flutter test --no-pub test/app_config_media_defaults_test.dart test/decoded_image_cache_budget_test.dart test/template_media_performance_test.dart --reporter=compact
dart analyze lib/core/performance/decoded_image_cache_budget.dart lib/app/app.dart test/decoded_image_cache_budget_test.dart test/template_media_performance_test.dart
flutter test --no-pub test/decoded_image_cache_budget_test.dart test/template_media_performance_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/templates_controller.dart lib/features/templates/presentation/templates_page.dart test/templates_controller_test.dart test/templates_page_lifecycle_test.dart
flutter test --no-pub test/templates_controller_test.dart --name "bounds thumbnail warmup to first preview candidates only" --reporter=compact
flutter test --no-pub test/templates_controller_test.dart --reporter=compact
flutter test --no-pub test/templates_controller_test.dart --name "clears stale visible cards before delayed cache lookup finishes" --reporter=compact
flutter test --no-pub test/templates_controller_test.dart test/templates_page_lifecycle_test.dart --reporter=compact
dart analyze lib/features/templates/data/templates_dto.dart lib/features/templates/presentation/templates_page.dart test/templates_remote_data_source_test.dart test/templates_page_lifecycle_test.dart
dart analyze lib/features/templates/data/templates_remote_data_source.dart test/templates_remote_data_source_test.dart
flutter test --no-pub test/templates_remote_data_source_test.dart --reporter=compact
flutter test --no-pub test/templates_page_lifecycle_test.dart --name "template selection loads detail payload before preview" --reporter=compact
flutter test --no-pub test/templates_page_lifecycle_test.dart --reporter=compact
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~TemplateResponses_ShouldIncludePetPhotoRequirements|FullyQualifiedName~PublicTemplateResponses_ShouldExposeGenerationInputCapabilitiesConsistently|FullyQualifiedName~PublicTemplatesFeed_ShouldKeepMobileJsonContractShape|FullyQualifiedName~PublicTemplatesFeed_ShouldPageAndFilterActiveTemplatesForAnonymousUsers" --no-restore
dart analyze lib/features/templates/presentation/templates_controller.dart lib/features/templates/presentation/templates_page.dart test/templates_controller_test.dart test/templates_page_lifecycle_test.dart
flutter test --no-pub test/templates_controller_test.dart --reporter=compact
flutter test --no-pub test/templates_controller_test.dart test/templates_page_lifecycle_test.dart --reporter=compact
dart analyze lib/features/templates/data/templates_remote_data_source.dart lib/features/templates/data/templates_repository.dart test/templates_remote_data_source_test.dart test/templates_repository_test.dart
dart analyze lib/features/templates/data/templates_cache_data_source.dart lib/features/templates/data/templates_repository.dart test/templates_repository_test.dart
dart analyze lib/features/templates/data/templates_cache_data_source.dart lib/features/templates/data/templates_remote_data_source.dart lib/features/templates/data/templates_repository.dart test/templates_remote_data_source_test.dart test/templates_repository_test.dart
flutter test --no-pub test/templates_remote_data_source_test.dart test/templates_repository_test.dart --reporter=compact
flutter test --no-pub test/templates_repository_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/widgets/template_flow_sheets.dart test/video_preview_lifecycle_test.dart
flutter test --no-pub test/video_preview_lifecycle_test.dart --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --reporter=compact
dart analyze lib/features/pets/presentation/my_pets_page.dart lib/features/templates/presentation/generation_status_page.dart lib/features/templates/presentation/generation_result_input_page.dart lib/features/templates/presentation/templates_page.dart lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart lib/features/templates/presentation/generations_gallery_page_cards.dart lib/shared/navigation/petmagic_shell.dart lib/core/notifications/push_notifications_bootstrap.dart test/widget_test.dart
dart analyze integration_test/gallery_cross_flow_test.dart
flutter test test/widget_test.dart --reporter=compact
flutter test test/generations_gallery_page_test.dart --reporter=compact
flutter test -d emulator-5554 integration_test/gallery_cross_flow_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/generation_status_page.dart lib/features/templates/presentation/generations_gallery_page.dart lib/features/templates/presentation/generations_gallery_page_states_and_actions.dart test/generations_gallery_page_test.dart test/generation_status_page_security_test.dart
flutter test test/generations_gallery_page_test.dart --reporter=compact
flutter test test/generation_status_page_security_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/generation_result_input_page.dart test/generation_result_input_page_test.dart
flutter test test/generation_result_input_page_test.dart --reporter=compact
flutter test test/widget_test.dart --name "app router registers pet details creations and generation status routes" --reporter=compact
dart analyze lib/features/templates/data/templates_remote_data_source.dart lib/features/templates/data/templates_repository.dart lib/features/templates/presentation/templates_controller.dart test/templates_remote_data_source_test.dart test/templates_controller_test.dart test/templates_controller_backend_data_source_test.dart test/templates_page_backend_feed_test.dart test/templates_page_lifecycle_test.dart test/widget_test_support.part.dart integration_test/gallery_cross_flow_test.dart integration_test/templates_feed_backend_stress_test.dart integration_test/templates_feed_http_backend_smoke_test.dart
flutter test --no-pub test/templates_remote_data_source_test.dart --name "cancelPendingMetadataRequests cancels active metadata requests" --reporter=compact
flutter test --no-pub test/templates_controller_test.dart --name "cancels in-flight feed load and ignores late result when screen hides" --reporter=compact
flutter test --no-pub test/templates_remote_data_source_test.dart test/templates_controller_test.dart --reporter=compact
dart analyze lib/core/performance/media_lifecycle_policy.dart lib/core/performance/template_preview_video_controller.dart lib/features/templates/presentation/widgets/template_flow_sheets.dart lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart test/video_preview_lifecycle_test.dart test/template_media_performance_test.dart
flutter test --no-pub test/video_preview_lifecycle_test.dart --name "template flow preview ignores stale async initialization" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --name "template flow video preview is visibility-gated and cached" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart test/video_preview_lifecycle_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/widgets/template_flow_sheets.dart lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart test/template_media_performance_test.dart
flutter test --no-pub test/template_media_performance_test.dart --name "template flow sheet media URLs are checked before rendering or sharing" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/generations_gallery_page.dart lib/features/templates/presentation/generations_gallery_page_cards.dart test/template_media_performance_test.dart
flutter test --no-pub test/template_media_performance_test.dart --name "generation gallery media URLs are checked before preview or copy" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/generation_status_page.dart test/template_media_performance_test.dart test/generation_status_page_security_test.dart
flutter test --no-pub test/template_media_performance_test.dart --name "generation status result media decodes with bounded cache sizes" --reporter=compact
flutter test --no-pub test/generation_status_page_security_test.dart --name "generation result aspect ratio probe is cached and detached" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/generation_result_input_page.dart test/template_media_performance_test.dart
flutter test --no-pub test/template_media_performance_test.dart --name "generation result input media decodes with bounded cache sizes" --reporter=compact
flutter test --no-pub test/generation_result_input_page_test.dart --reporter=compact
dart analyze lib/features/templates/presentation/templates_page.dart test/template_media_performance_test.dart
flutter test --no-pub test/template_media_performance_test.dart --name "template page pet shortcut avatar is cached at bounded size" --reporter=compact
flutter test --no-pub test/template_media_performance_test.dart --reporter=compact
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~ListPublicCatalogAsync_ShouldUseFeedVersionTieBreakOrder|FullyQualifiedName~ListPublicFeedAsync_ShouldStayBoundedAndStableWithMoreThanThousandTemplates|FullyQualifiedName~GetPublicRandomTemplateAsync_ShouldFilterByTypeCategoryAndPremiumAvailability" --no-restore
dart analyze lib/features/templates/data/templates_repository.dart lib/features/templates/data/templates_cache_data_source.dart test/templates_repository_test.dart
flutter test --no-pub test/templates_repository_test.dart --name "fetchCategories" --reporter=compact
flutter test --no-pub test/templates_repository_test.dart --reporter=compact
nslookup api.petmagic.app
curl -I --max-time 10 'https://api.petmagic.app/api/templates/feed?take=1'
curl -sS -D - -o /private/tmp/petmagic-api-template-feed-probe.json --max-time 15 'https://api.petmagic.app/api/templates/feed?take=1'
```

Latest focused rerun results:

```text
templates_page_backend_feed_test.dart: 3 passed
template_media_performance_test.dart + video_preview_lifecycle_test.dart + template_card_test.dart: 29 passed
template_media_performance_test.dart: 14 passed
template_media_performance_test.dart after thumbnail byte-budget cleanup: 15 passed
template_media_performance_test.dart + video_preview_lifecycle_test.dart + template_card_test.dart after thumbnail byte-budget cleanup: 30 passed
template_media_performance_test.dart + video_preview_lifecycle_test.dart + template_card_test.dart after template preview video source audit: 30 passed; targeted analyzer: no issues
template_media_performance_test.dart + template_card_test.dart + video_preview_lifecycle_test.dart after TemplateCard app-background video lifecycle release: 31 passed; targeted analyzer: no issues
combined feed/controller/backend-data-source/media-card focused suite after app-background video lifecycle release: 86 passed; targeted analyzer: no issues
templates_controller_test.dart + templates_remote_data_source_test.dart + template_random_selector_test.dart + templates_page_lifecycle_test.dart after template-of-the-day refetch, hidden-screen media prefetch, and stale thumbnail warmup guards: 51 passed; targeted analyzer: no issues
templates_controller_test.dart + templates_page_lifecycle_test.dart + templates_page_backend_feed_test.dart + templates_controller_backend_data_source_test.dart + templates_remote_data_source_test.dart after hidden-screen feed cancellation, empty-feed return reload, backend-order daily badge fix, and failed-feed cancel-token cleanup: 55 passed; targeted analyzer: no issues
templates_page_lifecycle_test.dart after preserving backend feed order with Template of the Day badge: 16 passed; targeted analyzer: no issues
external_url_policy_test.dart + production_networking_config_test.dart + app_config_security_test.dart: 19 passed
generation_gallery_store_test.dart after orphan artifact cleanup coverage: 15 passed; targeted analyzer: no issues
generation_history_controller_test.dart after local artifact cleanup scheduling: 29 passed; targeted analyzer: no issues
generation_history_controller_test.dart + generation_gallery_store_test.dart after local artifact cleanup scheduling: 44 passed
generation_result_input_page_test.dart + generation_history_controller_test.dart + generation_gallery_store_test.dart after result-input and unread-refresh lifecycle guards: 43 passed; targeted analyzer: no issues
generation_history_controller_test.dart + generations_gallery_page_test.dart: 49 passed
generation_gallery_store_test.dart + generation_history_controller_test.dart + template_generation_repository_test.dart: 52 passed
generation_status_page_security_test.dart + generation_history_controller_test.dart + generation_gallery_store_test.dart: 52 passed
generation_history_controller_lifecycle_test.dart + generation_history_controller_test.dart + generation_gallery_store_test.dart: 33 passed
session_scope_reset_test.dart: 1 passed
generation_status_page_security_test.dart: 17 passed
generations_gallery_page_test.dart: 22 passed; targeted analyzer: no issues
my_pets_page_test.dart after Pet Photos awaited refresh futures: 35 passed; targeted analyzer: no issues
templates_external_backend_smoke_test.dart analyze: no issues
templates_external_backend_smoke_test.dart on Android emulator-5554 without PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL: 1 passed, opt-in skip path verified
templates_external_backend_smoke_test.dart through QA runner on Android emulator-5554 without PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL: passed, artifact `artifacts/mobile-template-feed/android-emulator-template-feed-external-smoke-skip-20260615T021439Z`
templates_external_backend_smoke_test.dart after random premium-availability gate: analyze no issues; Android emulator-5554 skip path with `--no-pub` and `PETMAGIC_SKIP_FIREBASE=true` still passes 1/1
templates_external_backend_smoke_test.dart after deployed-feed sort-order gate: analyze no issues; Android emulator-5554 skip path with `--no-pub` and `PETMAGIC_SKIP_FIREBASE=true` still passes 1/1
run-template-feed-device-qa.sh after cache-delta budget gate and Android cache-only snapshot quoting fix: bash syntax passed; debug Android runner smoke artifact `artifacts/mobile-template-feed/android-emulator-external-smoke-cache-budget-gate-cacheonly-quoted-20260615T153000Z` passed with `cache_budget_failed: false`, `cache_budget_violation_count: 0`, and `private_cache_delta_kb: 0`
app router gallery route smoke in widget_test.dart: 1 passed
widget_test.dart + generations_gallery_page_test.dart + my_pets_page_test.dart after real appRouter smoke coverage: 72 passed
generations_gallery_mappers_test.dart: 6 passed; targeted analyzer: no issues
generations_gallery_mappers_test.dart + generations_gallery_page_test.dart + widget_test.dart + my_pets_page_test.dart: 90 passed
backend template catalog/API/hardening filtered dotnet test suite: 14 passed
backend database index model dotnet test suite: 4 passed
backend database index model dotnet test suite after public-feed category/order index: 4 passed
backend public catalog/feed/random targeted suite after catalog version tie-break alignment: 3 passed
ListPublicFeedAsync filter after public-feed category/order index: 7 passed
my_pets_page_test.dart + generations_gallery_page_test.dart: 34 passed
template_generation_repository_test.dart: 15 passed
template_generation_repository_test.dart + my_pets_page_test.dart: 46 passed
template_generation_repository_test.dart + my_pets_page_test.dart + generation_history_controller_test.dart + generations_gallery_page_test.dart: 62 passed
my_pets_page_test.dart + templates_page_lifecycle_test.dart after Pet Photos awaited refresh futures: 54 passed
templates_page_lifecycle_test.dart: 14 passed
template_generation_controller_test.dart: 13 passed
gallery_cross_flow_test.dart on Android emulator-5554 after generation-history visibility API update: 1 passed
gallery_cross_flow_test.dart through Android profile QA runner with production-safe CDN fixture: passed, artifact `artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-production-safe-profile-20260615T022457Z`
gallery_cross_flow_test.dart through Android profile QA runner with GSM network shaping: passed, artifact `artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-production-safe-gsm-20260615T023728Z`
gallery_cross_flow_test.dart on iOS simulator F18FB7FC-73CC-410D-9EB2-821BEC075E20 after generation-history visibility API update: 1 passed
gallery_cross_flow_test.dart on iOS simulator F18FB7FC-73CC-410D-9EB2-821BEC075E20 after production-safe CDN fixture update: 1 passed
gallery_cross_flow_test.dart through iOS simulator debug QA runner after Pet Photos action-state reset: passed, artifact `artifacts/mobile-template-feed/ios-simulator-gallery-cross-flow-current-debug-20260615T070421Z`
gallery_cross_flow_test.dart through Android profile QA runner after Pet Photos action-state reset: passed, artifact `artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-current-profile-20260615T070619Z`
gallery_cross_flow_test.dart through Android profile GSM QA runner after Pet Photos action-state reset: passed, artifact `artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-current-gsm-20260615T070733Z`
gallery_cross_flow_test.dart on Android emulator-5554 after local artifact cleanup scheduling: 1 passed
gallery_cross_flow_test.dart on iOS simulator F18FB7FC-73CC-410D-9EB2-821BEC075E20 after local artifact cleanup scheduling: 1 passed
templates_page_backend_feed_test.dart after visible backend loading/empty/error state coverage: 4 passed; targeted analyzer: no issues
templates_page_lifecycle_test.dart after active-filter return coverage: 17 passed; targeted analyzer: no issues
templates_page_lifecycle_test.dart after active-search-field return sync and deterministic GoogleFonts test setup: 18 passed; targeted analyzer: no issues
template_card_test.dart after deterministic thumbnail resolver coverage: 13 passed; targeted single test: 1 passed; targeted analyzer: no issues
template_card_test.dart after video preview image-fallback guard: 14 passed; targeted analyzer: no issues
template_media_performance_test.dart after TTL-aware remembered cache: 16 passed; targeted TTL regression: 1 passed; targeted analyzer: no issues
template_media_performance_test.dart after bounded Template of the Day hero thumbnails: 17 passed; targeted hero thumbnail regression: 1 passed; templates_page_lifecycle_test.dart: 17 passed; targeted analyzer: no issues
app_config_media_defaults_test.dart + decoded_image_cache_budget_test.dart + template_media_performance_test.dart after decoded image cache budget: 20 passed; targeted analyzer: no issues
decoded_image_cache_budget_test.dart + template_media_performance_test.dart after decoded image lifecycle trim: 21 passed; targeted analyzer: no issues
templates_controller_test.dart after bounded first-page thumbnail warmup: 27 passed; targeted warmup regression: 1 passed; targeted analyzer: no issues
templates_controller_test.dart after pre-cache stale visible card clearing: 29 passed; targeted regression: 1 passed; targeted analyzer: no issues
templates_controller_test.dart + templates_page_lifecycle_test.dart after pre-cache stale visible card clearing: 47 passed
templates_remote_data_source_test.dart after lightweight feed payload parsing: 9 passed; targeted analyzer: no issues
templates_remote_data_source_test.dart after encoded detail/analytics template paths: 12 passed; targeted analyzer: no issues
templates_page_lifecycle_test.dart after detail-on-tap template loading: 18 passed; targeted detail-on-tap regression: 1 passed; targeted analyzer: no issues
backend public templates feed contract targeted dotnet suite after lightweight feed payload: 4 passed
backend public templates feed video preview contract: 1 passed; sibling mobile JSON shape contract: 1 passed
templates_remote_data_source_test.dart + templates_repository_test.dart after paged-catalog full resync and bounded detail cache: 16 passed; targeted analyzer: no issues
templates_remote_data_source_test.dart + templates_repository_test.dart after encoded detail/analytics template paths: 18 passed; targeted analyzer: no issues
templates_repository_test.dart after stale catalog media cleanup: 8 passed; targeted analyzer: no issues
templates_remote_data_source_test.dart + templates_repository_test.dart after stale catalog media cleanup: 20 passed; targeted analyzer: no issues
templates_repository_test.dart after cached search field alignment: 9 passed; targeted analyzer: no issues
templates_remote_data_source_test.dart + templates_repository_test.dart after cached search field alignment: 21 passed; targeted analyzer: no issues
templates_repository_test.dart after cached backend-order tie alignment: 10 passed; targeted analyzer: no issues
templates_remote_data_source_test.dart + templates_repository_test.dart after cached backend-order tie alignment: 22 passed; targeted analyzer: no issues
templates_repository_test.dart after remote-first category metadata refresh: 12 passed; targeted category regressions: 2 passed; targeted analyzer: no issues
templates_controller_test.dart after Template of the Day thumbnail warmup best-effort guard: 28 passed; targeted analyzer: no issues
templates_controller_test.dart after hidden-screen categories guard: 30 passed; targeted regression: 1 passed; targeted analyzer: no issues
templates_remote_data_source_test.dart + templates_controller_test.dart after metadata request cancellation: 44 passed; targeted regressions: 2 passed; targeted analyzer: no issues
templates_controller_test.dart + templates_page_lifecycle_test.dart after Template of the Day thumbnail warmup best-effort guard: 46 passed
templates_page_lifecycle_test.dart after hidden-tab search debounce cancellation: 19 passed; targeted regression: 1 passed; targeted analyzer: no issues
templates_page_lifecycle_test.dart after hidden-tab random-template result guard: 20 passed; targeted regression: 1 passed; targeted analyzer: no issues
templates_remote_data_source_test.dart after random-template cancel token support: 13 passed; targeted regression: 1 passed; targeted analyzer: no issues
templates_page_lifecycle_test.dart after hidden-tab random-template request cancellation: 22 passed; targeted regression: 1 passed; targeted analyzer: no issues
templates_page_lifecycle_test.dart after active-only random-template cancel target cleanup: 22 passed; targeted regressions: 2 passed; targeted analyzer: no issues
templates_remote_data_source_test.dart + templates_page_lifecycle_test.dart after random-template request cancellation: 35 passed
templates_page_lifecycle_test.dart after dispose-safe random-template cancellation: targeted regression 1 passed; full file 21 passed; targeted analyzer: no issues
video_preview_lifecycle_test.dart after template-flow app lifecycle video release: 3 passed; targeted analyzer: no issues
template_media_performance_test.dart after template-flow app lifecycle video release: 18 passed
template_media_performance_test.dart + video_preview_lifecycle_test.dart after template-flow preview slot cap: 26 passed; targeted regressions: 2 passed; targeted analyzer: no issues
template_media_performance_test.dart after Template of the Day cached video preview: 21 passed; targeted analyzer: no issues
template_media_performance_test.dart after bounded template-flow result image decode: 23 passed; targeted regression: 1 passed; targeted analyzer: no issues
template_media_performance_test.dart after bounded generation-gallery thumbnails: 23 passed; targeted regression: 1 passed; targeted analyzer: no issues
template_media_performance_test.dart after bounded Generation Status result media: 24 passed; targeted regression: 1 passed; generation_status_page_security targeted aspect-ratio regression: 1 passed; targeted analyzer: no issues
template_media_performance_test.dart after bounded Generation Result Input media: 25 passed; targeted regression: 1 passed; generation_result_input_page_test.dart: 1 passed; targeted analyzer: no issues
template_media_performance_test.dart after bounded pet shortcut avatar cache: 26 passed; targeted regression: 1 passed; targeted analyzer: no issues
template_media_performance_test.dart + template_card_test.dart after bounded TemplateCard image decode width: 32 passed; targeted analyzer: no issues
template_media_performance_test.dart after stale in-flight media cache invalidation: 21 passed; targeted analyzer: no issues
template_media_performance_test.dart after bounded media invalidation bookkeeping: 21 passed; targeted analyzer: no issues
template_media_performance_test.dart after per-URL media invalidation isolation: 22 passed; targeted regression: 1 passed; targeted analyzer: no issues
template_media_performance_test.dart after invalidated preview-controller network fallback guard: 23 passed; targeted regression: 1 passed; targeted analyzer: no issues
template_media_performance_test.dart + template_card_test.dart + video_preview_lifecycle_test.dart after invalidated preview-controller network fallback guard: 41 passed
template_media_performance_test.dart + template_card_test.dart after stale in-flight media cache invalidation: 34 passed
template_card_test.dart after deferred stale video dispose during initialize: targeted lifecycle regression 1 passed; full file 15 passed; targeted analyzer: no issues
template_media_performance_test.dart after deferred stale video dispose during initialize: 23 passed
run-template-feed-device-qa.sh video playback log scanner: bash syntax passed; scanner returned 0 markers for the post-fix Android artifact and 5 markers for the pre-fix released-surface artifact
route helper hardening analyzer for Pet Details, Generation Status, Result Input, Templates, Creations cards/actions, shell active banner, push notification bootstrap, and widget_test.dart: no issues
gallery_cross_flow_test.dart harness analyzer after deterministic TemplatesRepository override: no issues
widget_test.dart after encoded PetDetails/GenerationStatus/Result Input route regression: 38 passed
generations_gallery_page_test.dart after shared GenerationStatus route helper adoption: 21 passed
gallery_cross_flow_test.dart on Android emulator-5554 after route helper adoption and deterministic preview harness: 1 passed
gallery_cross_flow_test.dart direct run without `-d`: not executed because Flutter detected Android emulator, iOS simulator, macOS, and Chrome targets; rerun with explicit `-d emulator-5554`
gallery_cross_flow_test.dart on `-d macos`: not applicable because the Flutter project has no macOS desktop target configured
generations_gallery_page_test.dart after Ready-card save/share filename sanitization: 22 passed; targeted analyzer: no issues
generation_status_page_security_test.dart after fallback save/share filename sanitization: 17 passed; targeted analyzer: no issues
generation_result_input_page_test.dart after result-input start lifecycle cancellation: 1 passed; targeted analyzer: no issues; route smoke: 1 passed; diff check: passed
```

Covered behavior:

- Feed uses backend feed contract instead of full catalog sync for normal loading.
- `/api/templates/feed` now returns a bounded card-rendering item shape that includes public generation capability metadata (`petPhotoRequirements`, generation-result capability flags, variation strength) plus item version stamps; detail, legacy list, and random-template responses remain full public template items for direct preview/generation flows.
- Mobile template-card selection fetches `/api/templates/{templateId}` before opening preview so the lightweight feed does not lose full generation metadata; failure falls back to the feed card payload, and random-template selection avoids a duplicate detail refetch.
- Mobile template detail and template analytics API calls encode template IDs as URL path segments, so reserved characters in backend-provided IDs cannot turn a detail or analytics request into a different route.
- Mobile full-catalog resync uses `/api/templates?page=...&pageSize=...` versioned catalog metadata and is regression-tested to avoid `/api/templates/feed`, preserving feed payload economy while keeping local catalog order/version metadata.
- Paged public catalog now uses the same `UpdatedAtUtc desc, Version desc, Id desc` ordering as `/api/templates/feed`, so mobile bootstrap/full-resync metadata cannot reorder templates differently from the backend feed when several items share the same update timestamp.
- Template detail fetches are deduplicated and cached in a bounded in-memory repository cache, so reopening the same template in the same session avoids repeat detail requests while the cache cannot grow beyond its limit. Random-template responses seed the same detail cache, catalog deltas evict changed template details, and late detail responses after catalog resync are guarded from repopulating stale cache entries.
- Catalog delta sync and full resync now clean stale template `thumbnailUrl` and `previewAsset.url` media after deletes or media URL replacements, while preserving shared media URLs that remain referenced by another template. Cleanup attempts both thumbnail and preview-video cache namespaces, so replaced image thumbnails and video previews do not wait only for TTL/budget eviction.
- Local cached first-page search now mirrors the backend searchable field set available in the catalog payload: title, short description, category, tags, and pet-photo requirements. This prevents a quick cached restore from showing an empty or mismatched search page before the backend refresh completes.
- Local cached catalog pages now sort by the same public-feed ordering keys available on mobile: `updatedAtUtc` descending, `version` descending, then template id descending. This keeps cached first paint aligned with backend/API order when templates share the same update timestamp.
- Template of the Day image thumbnail warmup is best-effort; cache/network failures are caught locally and do not clear featured state, feed state, or surface as unhandled async errors.
- `PetDetailsPage.location`, `GenerationStatusPage.routeFor`, and `GenerationResultInputPage.routeFor` encode dynamic path segments, and the real app router decodes IDs containing slash, space, query, and fragment-like characters back into the original `petId`/`generationId`, including the result-input route's repository status and compatible-template calls.
- Status navigation from Templates, Pet Details generation history, Creations ready/active/failed cards, Creations bottom sheets, the shell active-generation banner, and push notification deep links now uses one shared `GenerationStatusPage.routeFor` helper.
- Generation Result Input uses one lifecycle cancel token for template-selected analytics, start-from-result, and generation-started analytics; disposing the page cancels the in-flight start and ignores late completion without remembering a stale active generation, navigating, or showing an error toast.
- `gallery_cross_flow_test.dart` no longer depends on a real template-detail network fallback or a fixed 300 ms preview delay; its harness supplies a deterministic `TemplatesRepository` and waits for the preview action before continuing.
- Ready-card save/share and Generation Status fallback save/share file names sanitize both template title and generation id, so generation ids containing slash, query, fragment, or other reserved characters cannot leak unsafe path separators into local media file names.
- Controller plus real `TemplatesRemoteDataSource` keeps a 1005-item backend feed on cursor pages and cancels a stale delayed search request before showing the newer backend result.
- `TemplatesPage` with the real controller and real `TemplatesRemoteDataSource` renders backend cursor pages lazily, sends type/category filters to the backend feed without mixing old cards, debounces UI search, clears stale cards while searching, cancels the superseded delayed backend search, and shows only the latest backend result.
- Returning to the Templates tab with an active backend search now restores the visible search field text from `state.query.search`, while active debounce input is left untouched so partially typed search text is not wiped by unrelated rebuilds.
- Repeated backend feed changes across all/video/image type filters, category filters, search, search clearing, and cursor `loadMore` stay paged, keep visible cards bounded, avoid adjacent duplicate backend queries, retain only distinct item ids, and keep the in-memory feed cache bounded to six query keys.
- Real Dio/default HTTP client path is covered by a device integration target that talks to a local `HttpServer`, including cursor pagination, video/category filters, delayed stale search, latest-result rendering, and request/query capture.
- A new opt-in external backend smoke target can validate deployed `/api/templates/feed`, `/api/templates/categories`, and `/api/templates/random` directly for cursor pagination, type/category/search filtering, random selection, HTTPS media URLs, duplicate-free cursor pages, bounded `take=1000`, and card-sized feed payloads without internal/heavy generation fields. It skips safely when no deployed base URL is provided.
- `generations_gallery_mappers.dart` has direct coverage for filter subtitles, stage/ETA labels, photo-vs-technical failure hints, image/video labels and icons, preview URL selection for image/video generations, and safe video URL query/extension detection.
- `generations_gallery_page_test.dart` directly covers Ready-card delete from the bottom sheet, including optimistic item removal and unread badge update.
- `loadMore` uses backend cursor, appends without duplicates, and does not advance on stale cursor.
- Controller pagination keeps a 1005-item backend dataset paged, with only fetched pages accumulated in state.
- Duplicate `loadMore` calls while a cursor page is in flight do not issue duplicate backend fetches.
- Search/category/type `loadMore` keeps the same backend query and preserves backend item order across pages.
- Stale search responses are ignored when a newer backend query completes first.
- During delayed backend search, `TemplatesPage` clears the old visible cards immediately and shows the loading surface while the backend request is still in flight.
- During delayed local first-page cache lookup for a changed query, the controller now clears stale visible cards before awaiting disk cache or backend fetch, so old results are not shown under the new search/category/type while async cache lookup is pending. Previously visited in-memory query pages still restore immediately without a blank intermediate state.
- Superseded in-flight backend feed requests are cancelled before the newer query is sent.
- Stale `loadMore` responses are ignored after type/category/search changes and do not leave `isLoadingMore` stuck.
- Rapid category/type/search changes keep only the latest backend result visible even when older requests finish later.
- Search input is debounced before calling the backend-backed controller query.
- Pending UI search debounce is cancelled when the Templates tab hides or the app leaves the resumed state, so a hidden/offstage screen cannot issue a delayed backend search request.
- Duplicate normalized search values do not issue additional feed requests.
- Identical in-flight initial feed loads are deduplicated into one backend fetch.
- Delayed category metadata responses are ignored after the Templates screen hides, so secondary category/filter state cannot mutate hidden UI after a lifecycle cancellation.
- Secondary template metadata requests (`/api/templates/categories` and `/api/templates/template-of-the-day`) carry cancel tokens and are cancelled when the Templates screen hides or disposes, so hidden feed screens do not keep category or featured-template HTTP work alive.
- Category metadata now prefers fresh `/api/templates/categories` responses over any locally cached catalog-derived categories, while falling back to local catalog categories on ordinary API failures. This avoids stale filter chips after backend-side category changes without making categories depend on already loaded feed cards.
- The auxiliary Template of the Day request is not repeated during ordinary type/category/search feed reloads after it is already loaded; explicit refresh still reloads it.
- Feed thumbnail warmup is guarded by request version and query key between prefetches, so a fast filter/type/search change stops additional stale media warmup from the old feed query.
- First-page thumbnail warmup is capped to the first six preview candidates and regression-tested with a 50-item backend page, so media prefetch does not download every thumbnail returned by a paged API response.
- Template of the Day loads that finish after the Templates tab is hidden are ignored and do not start thumbnail prefetch, avoiding hidden-screen media traffic and stale UI mutation.
- Hiding the Templates tab cancels the active backend feed request through the repository/data-source path, clears loading flags without surfacing an error, ignores late feed results, and avoids stale media warmup from that hidden request.
- Returning to an empty Templates tab bypasses the refresh cooldown and reloads the feed, while returning to an already loaded tab still avoids an unnecessary reload.
- Returning to the Templates tab with active `type=Video`, category, and search filters preserves the filtered query, `itemsQueryKey`, and visible feed card without issuing another initial feed load.
- Template of the Day can still render a feed badge, but it no longer promotes/reorders the card in the paged grid; visible cards keep backend/API order.
- Failed backend feed requests clear their active cancel token, so later feed loads do not keep or cancel stale completed request tokens.
- Clearing search returns to the default backend feed query instead of filtering only already loaded search results.
- Empty backend search results clear previous feed cards and expose the empty state.
- Filter load errors clear stale cards and expose the error state without mixing old results.
- `TemplatesPage` visible UI now covers backend empty search and backend timeout error after an existing feed: the old `template-0000` card disappears, the localized empty/error message is shown, and each search query is requested once.
- Filter/query cache behavior is isolated by query key.
- In-memory feed page cache is bounded to the latest six query keys during repeated filter changes.
- Random template selection uses backend selection and passes mode/category/premium filters.
- Random template backend results are ignored if the Templates tab becomes hidden before the response completes, and the active `/api/templates/random` Dio request is cancelled on tab hide/app background/dispose. An offstage Templates screen cannot keep a random request alive, open a preview, or show stale random-result UI.
- Template page random-request dispose now uses the already cached repository reference instead of reading Riverpod providers from `State.dispose`, preventing the unmount-time `Bad state: Using "ref" when a widget is about to or has been unmounted is unsafe` failure seen in the Android profile runner.
- The random-template cancel target is scoped only to the active `/api/templates/random` fetch and is cleared before opening the preview route, so completed random selections do not keep stale repository/data-source references or receive later hidden-screen cancel calls.
- The real Dio/default HTTP device smoke now calls `/api/templates/random` after the feed is filtered to `type=Video`, `category=Search`, and `search=dog`; it verifies `all` omits `type` while sending category/premium, `image` sends `type=Image`, `video` sends `type=Video`, and all returned random ids are outside the currently loaded `dog-template-*` feed cards.
- Template page keeps browsing UI stable across tab visibility changes.
- 1005-item template feed keeps a lazy `SliverGrid.builder` surface during fast scroll.
- Template video cards use visibility-gated playback and stale async init guards.
- Template video cards abandon in-flight preview initialization when a card leaves the viewport, without creating a native player for the stale request.
- Template video cards now defer disposing a stale native controller until `VideoPlayerController.initialize()` completes, preventing the Android ExoPlayer race where a fast viewport/lifecycle transition releases the surface while MediaCodec is still configuring it.
- Template video cards apply muted looping playback configuration before visible preview playback.
- Template card, template detail/flow, and generation preview video controllers await looping/mute configuration before initialization/playback, removing a race where playback could start before preview settings finished applying.
- Template video cards cap concurrent visible preview slots and release slots when cards leave the tree.
- Template video cards observe app lifecycle, release their preview controller slot immediately on app background/pause, dispose the native controller, and only recreate playback on app resume when the card was still visibly in the viewport.
- Template flow video previews also observe app lifecycle, dispose their native controller when the app becomes inactive/hidden/paused/detached, and only recreate cached preview playback on resume when the preview is still visible.
- Template detail/flow video previews now also participate in the shared active preview slot cap, so detail sheets and generation result previews cannot create unbounded native video controllers alongside visible feed cards.
- Template detail/flow video preview uses shared preview cache and visibility lifecycle.
- Template image paths use bounded thumbnail cache, placeholders, and safe URL parsing.
- Template image cards prefer thumbnail URLs over heavier image preview/original URLs.
- `TemplateCard` uses the same tested image preview resolver during card build; it prefers `thumbnailUrl` over image `previewAsset.url` and falls back to the image preview asset only when no renderable thumbnail is present.
- Video template cards use a renderable thumbnail URL for image fallback when present and never route an `.mp4`/video preview URL through the image thumbnail cache path when no thumbnail is available.
- Image card rendering remains pinned to `TemplateMediaCache.fetchThumbnailFile` plus local `Image.file`, so the list path avoids direct original/network image rendering for card thumbnails.
- Template image card decode width is always non-null and clamped even when layout constraints or pixel ratio are invalid, preventing a fallback to full-size thumbnail/original decode in long feed sessions.
- Template flow generated image result preview now also uses a layout-derived bounded `memCacheWidth` and `maxWidthDiskCache`, so returning from a template generation does not decode/cache a full-size output image in the sheet.
- Generation gallery thumbnail cards now use the same bounded 320px policy for local file decode, memory cache width, disk cache width, and medium filter quality, preventing gallery cards from storing or decoding full-size preview/output images during long sessions.
- Generation Status result media now bounds local-file decode, memory cache width, disk cache width, fullscreen image decode, and before/after compare image providers, so result review cannot cache or decode full-size generated images during long sessions.
- Generation Result Input parent previews and compatible-template thumbnails now also use named bounded memory/disk cache widths and medium filter quality, so starting from a generated result does not cache full-size preview media.
- Template page pet shortcut avatars are also bounded to a small memory/disk cache width, removing the last unbounded `CachedNetworkImage` on the Templates screen.
- Template of the Day hero media also uses `TemplateMediaCache.thumbnailCache`, bounds memory and disk cache width from the rendered card constraints, and shows the same media fallback while loading or on error.
- Template of the Day video hero media uses the shared cached preview-video controller, participates in the same active preview slot cap as feed cards, gates load/play by viewport visibility, mutes and loops playback, releases the native controller on hidden/background lifecycle states, and keeps a cached thumbnail/fallback behind the video.
- Template thumbnail and preview video caches reuse downloaded files for identical URLs instead of redownloading them.
- Template thumbnail and preview video cache helpers keep bounded in-memory file-reference maps, so repeated visible card rebuilds reuse already downloaded files without holding decoded media bytes.
- Explicit thumbnail/video cache removal and whole-cache cleanup invalidate in-flight media downloads; late thumbnail/video completions are rejected, stale cache-manager entries are removed best-effort, and a newer fetch generation for the same URL is protected from being deleted by an older completion.
- Explicit thumbnail/video cache removal now invalidates only the removed URL, so cleaning a stale media item cannot cancel unrelated in-flight thumbnail or preview downloads during a busy feed scroll.
- Invalidated video preview cache downloads no longer fall back to a direct network-backed `VideoPlayerController`; the stale controller init fails fast so the next visible retry goes through the shared preview cache/dedupe path.
- Media cache invalidation, latest-fetch, and blocked-url bookkeeping use bounded ordered maps/sets and are cleared during whole-cache cleanup, preventing repeated explicit media removal from growing service state without limit during long sessions.
- Remembered thumbnail and preview video file references now preserve cache-manager `validTill` metadata and are treated as unusable after expiry, so a long-running app session cannot keep serving stale remembered media while bypassing TTL refresh.
- Expired remembered thumbnail and preview video files are regression-tested to trigger exactly one fresh HTTP download per URL before being reused again.
- Template thumbnail and preview video caches both have best-effort byte-budget directory trimming that removes oldest cached files first, in addition to object-count and TTL limits.
- Remembered thumbnail/video file cache hits use a direct local file existence check, avoiding an extra async file-system hop on the hot rebuild path.
- App startup now installs a bounded decoded Flutter `ImageCache` budget, capped by production-safe app config defaults, so long template-feed scroll sessions cannot retain unbounded decoded image resources even when disk/file caches are controlled.
- The app shell observes lifecycle changes and trims decoded `ImageCache` keep-alive/live entries whenever the app leaves `resumed`, then reapplies the decoded cache budget on resume; disk thumbnail/video caches remain intact for reuse.
- Template cards render cached `Image.file` thumbnails and do not fall back to an uncached `Image.network` path after cache/decode failures; explicit retry invalidates the failed cache entry before trying again.
- Concurrent preview video cache fetches for the same URL are coalesced into a single download.
- Template card preview controller creation uses cached preview video files when present, so repeated card visibility for the same video URL creates file-backed controllers instead of falling back to a fresh network controller.
- `TemplateCard` widget lifecycle now covers the default cached video preview path across disposal and rebuild: a remembered preview file creates file-backed controllers on both mounts without falling back to the original network URL.
- Template card preview controller creation downloads a video preview URL once through the shared preview cache, then creates subsequent controllers from the cached file without another HTTP request.
- Template card and template flow video previews now share the same cached preview controller helper, so both surfaces use the same file-cache-first behavior and fallback semantics.
- Template preview video source audit is pinned by a regression check: `TemplateCard` contains no direct `VideoPlayerController.networkUrl` construction, and template detail/flow preview passes `useSharedPreviewCache: true` before reaching the shared cached controller helper. The remaining direct `networkUrl` path in `_NetworkVideoPreview` is guarded behind `!useSharedPreviewCache` for generated result/output media, not template preview cards.
- Real-HTTP Android profile, Android GSM, and iOS simulator smoke runs now activate visible video cards and verify a shared video preview URL is requested exactly once across filter/category/search rebuilds.
- Preview video cache byte-budget cleanup removes oldest cached files first and keeps the remaining directory under the configured size limit.
- Generation gallery local media reuse avoids redownloading usable files.
- Generation gallery local media revalidates existing preview/output files and redownloads corrupted local media instead of reusing invalid files.
- Generation gallery local media refreshes when the remote output URL changes, stores the new file under a URL-stamped path, and deletes stale files for that generation prefix.
- Generation gallery partial record updates preserve existing local media paths instead of clearing cached preview/output files during metadata-only writes.
- Generation gallery local media validation rejects empty downloaded files, does not mark the record complete, and leaves no local media file behind.
- Generation gallery local media validation rejects non-empty files without a supported image/video signature, leaves the record incomplete, and deletes temp files.
- Generation gallery local media download rejects unsafe remote URLs before any network request, leaves the record incomplete, and creates no media files.
- Generation gallery treats account and generation IDs as safe local filesystem path segments, so cache delete/cleanup cannot traverse outside the intended gallery cache scope even if a corrupted ID contains `../`.
- Generation gallery coalesces in-flight local media downloads by account scope plus generation ID, so identical generation IDs from different accounts do not share local paths, records, or cancel tokens.
- Generation gallery `removeRecord` clears the final persisted record for a scope and deletes that generation's media directory, so removed local media does not reappear after a store reload.
- Generation gallery `purgeAllScopes` removes persisted ready records and media directories for every known account scope during session reset, not only the current session scope.
- Generation gallery ready cache pruning retains pending delete tombstones.
- Generation gallery ready cache pruning deletes pruned generation media directories from disk while retaining directories for still-cached generations.
- Generation history keeps cached items visible on refresh failure, shows the offline banner, shows the recovered banner after the next successful refresh, hides the recovered banner after three seconds, and backs auto-refresh polling off from 8 seconds up to 30 seconds before resetting after success.
- Generation history queues the latest filter change while a history load is in flight, then loads that filter after the current request finishes without parallel duplicate fetches.
- Generation history clears a queued filter load when the gallery screen hides during an in-flight history load, so the queued filter does not start a hidden backend fetch or unread-count fetch after cancellation.
- Generation history cancels an in-flight history load when the gallery screen hides, clears the loading state, does not start the cancelled load's post-load unread-count fetch, supports a quick return/reload, and does not convert request cancellation into offline/error UI state.
- Generation history cancels gallery-dispose loads without writing a final loading-state update into a disposed UI listener, preventing Riverpod defunct-element rebuilds during route teardown.
- Generation history treats optimistic delete as locally complete after tombstone creation, keeps pending server deletes when the immediate server delete fails, retries them on the next sync, clears pending state after success, and keeps tombstoned remote generations hidden.
- Generation history does not start the immediate server delete if the controller is disposed while the local tombstone write is still in flight; the pending tombstone stays persisted for the next sync instead of issuing a hidden-screen API call.
- Generation history stops pending server-delete flush when the active history load is cancelled while the screen hides, so later pending tombstones are not retried from a hidden screen and no cancelled load proceeds into `fetchGenerations` or its post-load unread-count fetch.
- Generation history also stops pending server-delete flush after the first ordinary delete failure in a sync, keeping remaining tombstones for the next sync while still allowing the current history load to fetch and render with tombstoned remote items hidden.
- Generation history keeps tombstoned remote generations hidden and removes their server unread contribution even when the pending server-delete retry fails again.
- Generation history keeps pending and successfully server-deleted unread generations out of the badge during standalone unread-count refresh until the next full history sync, so a raw/stale server unread count cannot reintroduce hidden optimistic-delete items.
- Generation history ignores late standalone unread-count refresh results after the Creations screen is hidden, so hidden-screen badge state is not mutated by an old response.
- Generation history standalone unread-count refreshes pass cancel tokens to the repository, cancel when the gallery hides, and cancel superseded unread refreshes so stale badge responses do not apply and hidden screens do not keep unread-count requests alive.
- Generation history subtracts tombstoned unread generations found in the persistent all-history cache even when the current load is for a narrow filter such as Ready, keeping the global unread badge consistent across filters.
- Generation history ignores realtime status updates for locally tombstoned generations, so a deleted item is not reinserted or materialized by a late status event.
- Generation history controller applies a completed realtime update across in-memory filter caches, moving the item out of Active and into Ready, then applies downloaded local preview/output paths to the Ready cache entry.
- Generation history persists realtime status updates into existing persistent filter caches, moving completed items out of Active and into Ready cache buckets.
- Generation history realtime persistent-cache updates skip corrupted cache buckets without breaking valid filter buckets or realtime UI state.
- Generation history cancels active local media downloads when the Creations screen hides/disposes and ignores completed local media records while hidden, preventing hidden-screen media work from mutating gallery state.
- Generation history schedules orphan local media artifact cleanup once when the Creations screen first becomes visible, avoiding repeated filesystem scans across tab hide/show while preventing old unreferenced generation media directories from accumulating.
- Generation gallery store cleanup removes orphan generation media directories and stale `.part` files for the current account scope while leaving valid known-generation media and other account scopes untouched.
- Generation history disconnects a realtime connection that completes after the gallery screen has already been hidden, preventing hidden-screen realtime work from staying active.
- Generation history clears unread state and decrements the local unread count before the server mark-read request completes, keeps that local read state if server mark-read fails, applies it across stale filtered cache/remote refreshes while sync is in flight, and still attempts `markGenerationRead`.
- Generation history keeps a successfully marked-read item locally read across stale realtime/cache updates while no longer suppressing unrelated unread badge counts after the server mark-read call succeeds.
- Creations UI renders the not-authenticated, loading+empty, error+empty, empty, data-online, data-offline, and data-recovered states.
- Creations offline banner retry button uses a finite local minimum size so it does not inherit the app-wide full-width FilledButton style inside a horizontal banner row.
- Ready-card media actions cancel active save/share work on gallery disposal and ignore save/share taps while another media action is in flight.
- Pet Photos -> Templates passes the selected `petPhotoId` into generation start.
- Templates/Pet Photos/Creations test harnesses remain compatible with the generation-history visibility API after adding silent dispose cancellation.
- The real `appRouterProvider` registers and builds My Pets, Pet Details, Creations, Generation Status, and Generation Result Input routes with the expected `petId` and `generationId` path parameters; this complements the cross-flow tests that use local GoRouter harnesses.
- Android emulator and iOS simulator cross-flow coverage verifies Pet Photos -> Templates -> Generation Status -> Creations, including pet id/photo id propagation, result visibility, open-status, save, share, and optimistic delete actions.
- The generated pet-photo result is visible in Creations after the status route.
- Creations All filter renders Active/Ready/Failed sections, keeps overflow Ready cards collapsed by default, and expands/collapses the Ready grid through the show-more control.
- Creations Active filter renders only active generations with visible stage, percent progress, and ETA.
- Creations Failed filter renders only failed generations with a visible failure reason, refund note, and retry/support recovery actions.
- Creations Ready-card actions can save, share, open the generated status from the card or bottom sheet, mark the result read, and optimistically delete the result from the gallery.
- Creations Ready-card save action passes a safe output URL into the gallery media saver and does not invoke share.
- Creations Ready-card report-problem action closes the sheet and opens the support route.
- Creations Ready-card save/share/copy actions reject unsafe output URLs before invoking media actions or writing to the clipboard.
- Creations Ready-card copy-link action catches platform clipboard failures and shows a failure toast instead of surfacing an unhandled async exception.
- Creations Ready-card tap opens the status route immediately while unread mark-read sync is still in flight.
- Creations repository encodes generation, result, and template IDs as path segments for status, compatible-template, generate-similar, watermark, analytics, download/share, mark-read, and delete API calls while preserving raw IDs in request payloads and local cache/tombstone operations.
- Generation Status cancels active local media sync downloads on disposal/deactivation/backgrounding and guards local media apply by mounted/page-active/resumed lifecycle state.
- Generation Status rejects unsafe backend media access URLs before invoking save/share media actions, even when a signed access response is malformed or untrusted.
- Pet Photos routes show the shared auth gate for guests and do not start pets, photo, or pet-generation provider fetches while unauthenticated.
- Pet Photos renders the empty grid state (`No photos yet.`) without photo action buttons when a pet has no photos.
- Pet Photos renders photo-grid skeletons while photo data is loading, then swaps to the thumbnail-backed grid without exposing photo actions early.
- Pet Photos photo-load errors render the inline retry state immediately, retry only the photo provider on tap, and do not perform hidden provider-level retry requests.
- Pet Photos action invalidation refetches photo data after avatar/favorite/delete, refetches pet summaries after avatar/delete, and avoids an unnecessary pet-summary refetch on favorite-only changes.
- Pet Photos favorite action is covered in both directions: marking a non-favorite photo favorite and unmarking an already favorite photo.
- Pet Photos successful add-photo upload invalidates both pets and pet-photo data, causing both providers to refetch after upload.
- Pet Photos add-photo upload surfaces the `pets.photo_type_not_allowed` failure as a specific unsupported-type message instead of a generic upload failure, without invalidating photo data after the failed upload.
- Pet Photos ignores duplicate action taps while an avatar/favorite/delete request is in flight, preventing duplicate CRUD calls and extra refetches.
- Pet Photos disables `Use for generation` while a photo avatar/favorite/delete action is in flight, so navigation cannot start from a photo with pending CRUD state.
- Pet Photos preserves route-reserved pet IDs through the My Pets `Create with pet` route into Templates query parameters without adding a `petPhotoId`, so pet-only generation starts from the original `petId`.
- Pet Photos preserves route-reserved pet and photo IDs through the Pet Details `Use for generation` route into Templates query parameters, so the Templates flow receives the original `petId` and `petPhotoId`.
- Pet Photos ignores duplicate add-photo taps while image picking/upload is in flight, preventing parallel upload calls before the post-upload invalidation/refetch.
- Pet Photos cancels an active add-photo upload and clears stale add-photo busy state when navigating directly from one pet detail route to another.
- Pet Photos cancels active photo-action requests and clears stale busy state when navigating directly from one pet detail route to another.
- Pet Photos ignores stale upload/action completions from the previous pet route, so an old completion cannot clear busy state for a newer add-photo upload or avatar/favorite/delete action on the next pet.
- Pet Photos keeps a 500-photo grid lazy and reuses the cached photo load during a quick route return.
- Pet Photos fetch providers pass cancel tokens for pets, photos, and pet generations; the tokens are cancelled when the provider scope is disposed while preserving quick-return cache reuse.
- Pet Photos pull-to-refresh invalidates and awaits the pets, photo-grid, and pet-generation provider futures instead of completing the refresh gesture before the refetches finish.
- Pet Photos add-photo uploads and active avatar/favorite/delete photo actions pass cancel tokens and cancel them on page/grid dispose before invalidating data.
- Pet Photos treats Dio/CancelToken cancellations for add-photo uploads and photo actions as silent cancellations, not user-visible CRUD/upload failures.
- Pet Photos ignores late add-photo upload failures after the details page has been disposed, so stale upload errors cannot show a snackbar or mutate a removed UI.
- Pet Photos ignores late avatar/favorite/delete failures after the photo grid has been disposed, so stale action errors cannot show a snackbar or mutate a removed UI.
- Pet Photos ignores unsafe thumbnail/original URLs, falls back from an unsafe thumbnail to a safe original URL, and shows the broken-image fallback when no safe media URL is available.
- Pet Details generation-history share action rejects unsafe generation output URLs before invoking platform share.
- Pet Photos upload rejects declared non-image content, spoofed file bytes, and missing local files before multipart upload without exposing local paths, and uses detected media content type for valid uploads.
- Pet Photos repository encodes pet and photo IDs as path segments for fetch/upload/avatar/favorite/delete/generation-history API calls, so route-reserved characters cannot change the requested endpoint.
- Pet Photos repository forwards caller `CancelToken`s into fetch, upload, avatar, favorite, and delete HTTP requests so UI cancellation reaches the Dio request boundary.
- Creations keeps a 300-item Ready grid lazy during scroll.

### Backend template tests

Commands that passed:

```sh
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~TemplatesServiceTests"
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~TemplatesApiIntegrationTests"
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~ListPublicFeedAsync_ShouldSearchAcrossTitleDescriptionCategoryTagsAndRequirements"
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~ListPublicFeedAsync"
dotnet test tests/PetMagic.Modules.Identity.Tests/PetMagic.Modules.Identity.Tests.csproj --filter "FullyQualifiedName~DatabaseIndexModelTests"
```

Latest focused rerun results on the current worktree:

```text
TemplatesServiceTests filter: 91 passed
TemplatesApiIntegrationTests filter: 41 passed
ListPublicFeedAsync_ShouldSearchAcrossTitleDescriptionCategoryTagsAndRequirements: 1 passed
ListPublicFeedAsync filter: 7 passed
DatabaseIndexModelTests after public-feed category/order index: 4 passed
ListPublicFeedAsync filter after public-feed category/order index: 7 passed
```

Covered behavior:

- Public feed supports cursor pagination, category/type/search filters, and API ordering.
- Template DB metadata now includes a partial public-feed category/order index on `Status, Category, UpdatedAtUtc, Version, Id`, keeping category-filtered cursor pages aligned with the backend sort path.
- Public feed search is explicitly pinned across title, short description, category, tags, and pet-photo requirements.
- Public feed handles 1000+ templates without returning all rows at once.
- Public contracts expose thumbnail URL for card payloads without heavy detail fields.
- Public feed serialized JSON is pinned to the mobile card payload shape at root, item, and `previewAsset` levels, and explicitly excludes prompt/model/reference-motion/admin-cost/timestamp fields from feed items.
- Public random template endpoint respects category, type, activity, and availability filters.
- `type=all` is accepted by public feed/catalog endpoints.
- Backend filtered test evidence now covers public feed cursor pagination, search/category/type filtering, 1005-template bounded responses, random template filtering, mobile JSON payload shape without heavy/internal fields, video feed preview metadata with `thumbnailUrl=null`, provider-safe cursor behavior, and public feed hot-path indexes.

### Android device smoke

Commands that passed on `sdk gphone64 arm64` / `emulator-5554`:

```sh
flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/templates_feed_stress_test.dart -d emulator-5554 --no-dds
flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/gallery_cross_flow_test.dart -d emulator-5554 --no-dds
RUN_ID=android-emulator-template-feed-sampled-20260614T230942Z DEVICE_ID=emulator-5554 MODE=profile ANDROID_SAMPLE_INTERVAL_SECONDS=3 scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-gsm-20260614T231225Z DEVICE_ID=emulator-5554 MODE=profile NETWORK_SPEED=gsm ANDROID_SAMPLE_INTERVAL_SECONDS=3 scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-gallery-cross-flow-profile-20260614T231753Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-stress-profile-20260614T232003Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_stress_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-backend-stress-20260614T233403Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_backend_stress_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-backend-gsm-20260614T234818Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_backend_stress_test.dart NETWORK_SPEED=gsm ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-backend-long-session-20260615T000929Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_backend_stress_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-backend-long-session-cache-budget-20260615T023013Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_backend_stress_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-backend-20260615T002002Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-media-20260615T004429Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-media-filecache-20260615T010420Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-media-filecache-gsm-20260615T011930Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart NETWORK_SPEED=gsm ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-video-cache-20260615T015151Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-video-cache-gsm-20260615T015611Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart NETWORK_SPEED=gsm ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-cache-budget-profile-20260615T021939Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-cache-budget-gsm-20260615T022056Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart NETWORK_SPEED=gsm ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-valid-video-20260615 DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-valid-video-gsm-20260615 DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart NETWORK_SPEED=gsm ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-random-20260615 DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-random-modes-20260615 DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-type-transitions-20260615 DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-network-bytes-post-video-dispose-fix-20260615T122500Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-template-feed-http-logscan-post-random-dispose-fix-final-20260615T132000Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-gallery-cross-flow-actions-profile-20260614T235941Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-gallery-cross-flow-save-share-profile-20260615T000445Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=android-emulator-gallery-cross-flow-production-safe-profile-20260615T022457Z DEVICE_ID=emulator-5554 MODE=profile TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
```

Template feed stress scenario:

- Builds and installs the profile APK.
- Renders a 1005-item feed.
- Verifies first-frame and post-scroll `TemplateCard` counts stay bounded.
- Performs repeated fast flings.
- Jumps near the end and verifies the pagination trigger calls `loadMore`.
- Emits `templates_feed_fast_scroll` integration response data.

Backend-backed feed stress scenario:

- Builds and installs the profile APK.
- Renders `TemplatesPage` with the real `TemplatesController`, real `TemplatesRemoteDataSource`, and a fake Dio backend with 1005 available templates.
- Verifies the first page loads 20 items and the visible `TemplateCard` count stays bounded.
- Exercises repeated fast flings, cursor `loadMore`, UI video type filter, UI category filter, controller-driven delayed search cancellation, and latest search result rendering.
- Asserts the backend feed uses `cursor=cursor-20`, does not send page query parameters, sends `cat` then `dog` search requests, cancels the stale `cat` search, and ends on only the latest `dog` backend results.
- Runs an additional long-session loop of 12 backend-backed cycles across all/video/image type filters, category toggles, search terms, and cursor `loadMore`, recording duplicate request, cursor, cache, visible-card, and duplicate-item counters.
- Captures Android memory/cache snapshots through the runner and emits `templates_feed_backend_filter_search` plus `templates_feed_backend_workflow` response data when `FLUTTER_TEST_OUTPUTS_DIR` is set by the QA runner.

Real-HTTP backend smoke scenario:

- Builds and installs the profile APK.
- Renders `TemplatesPage` with the real `TemplatesController`, real `TemplatesRemoteDataSource`, default Dio HTTP adapter, and a local `dart:io` `HttpServer` bound to `127.0.0.1` on the device.
- Verifies first page `take=20`, cursor `loadMore`, video type filter, category filter, delayed stale `cat` search, latest `dog` search rendering, and no `page` query parameters.
- Exercises `Video -> All -> Image -> Video` type transitions: returning to already loaded `All` and `Video` filters restores the isolated in-memory feed page without extra HTTP requests, while switching to `Image` sends one fresh `type=Image` backend query and clears stale video cards.
- Waits for the delayed `cat` HTTP response to finish after `dog`; final visible items remain only `dog-template-000..002`, with no duplicate ids and no loading state left behind.
- Returns shared thumbnail and preview URLs in feed card payloads and verifies the shared thumbnail is requested exactly once across first render, cursor pages, video/category filters, delayed search cancellation, and latest search rendering.
- Activates visible video `TemplateCard` previews after the video filter and verifies the shared video preview URL is downloaded exactly once across video filter, category rebuild, stale search, and latest search rendering.
- The local HTTP fixture now serves a valid short MP4 preview, and the latest Android profile rerun confirms `flutter-drive.log` has no `UnrecognizedInputFormatException`, `ExoPlaybackException`, `NoDeclaredBrand`, or video source-error markers.
- Uses Android profile cleartext only for the profile variant so the profile integration APK can talk to local HTTP; the main production manifest remains cleartext-disabled.
- The QA runner adds `--dart-define=PETMAGIC_ALLOW_LOCAL_MEDIA_HTTP=true` only for this local real-HTTP smoke target. Default production media policy remains HTTPS allowlist based; explicit unit coverage verifies local HTTP is rejected when `allowLocalHttp` is disabled.

External backend smoke scenario:

- Target: `integration_test/templates_external_backend_smoke_test.dart`.
- By default, the test records a skipped `templates_external_backend_smoke` report and exits cleanly when `PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL` is not provided.
- With a deployed HTTPS base URL, it calls the public API directly through Dio, parses feed payloads with the mobile DTOs, and reuses `TemplatesRemoteDataSource` for categories/random endpoint coverage.
- It validates `GET /api/templates/feed` first page `take=20`, oversized `take=1000` server cap `<= 50`, optional second cursor page without duplicate ids or overlap, `Image` and `Video` type filters without mixing, category filter, backend search, feed freshness metadata, backend order by `updatedAtUtc` descending with `version` tie-breaks, and random template selection with type/category/premium parameters.
- It fails the deployed random-template probe if `/api/templates/random?includePremium=false` returns a premium template; random reports include `include_premium`, `template_present`, and `is_premium` for audit.
- It rejects feed item payloads that include heavy/internal generation fields such as prompts, model/provider payloads, status, create/delete timestamps, or raw assets, and requires card media URLs to be HTTPS. Public `version` and `updatedAtUtc` are required for visible-card freshness and order verification.
- Verified command: `flutter test -d emulator-5554 integration_test/templates_external_backend_smoke_test.dart --dart-define=PETMAGIC_SKIP_FIREBASE=true` passes the safe skip path.
- Latest verified command after the random premium-availability gate: `flutter test -d emulator-5554 --no-pub integration_test/templates_external_backend_smoke_test.dart --reporter=compact --dart-define=PETMAGIC_SKIP_FIREBASE=true` passes the safe skip path.
- Verified runner artifact: `artifacts/mobile-template-feed/android-emulator-template-feed-external-smoke-skip-20260615T021439Z` passes with `completion_marker: all_tests_passed_log`, `driver_request_result: true`, `integration_response_data: true`, and `metrics-summary.md` showing `External Backend Smoke` stage `skipped` with reason `missing PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL`.
- Attempted deployed command with `PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL=https://api.petmagic.app` built and installed on Android, but failed before API validation because DNS currently returns NXDOMAIN for `api.petmagic.app`. Host checks also failed: `nslookup api.petmagic.app` returned NXDOMAIN and `curl -I 'https://api.petmagic.app/api/templates/feed?take=1'` returned `Could not resolve host`.
- Rechecked on 2026-06-15: `nslookup api.petmagic.app` still returns NXDOMAIN and `curl -I --max-time 10 'https://api.petmagic.app/api/templates/feed?take=1'` still returns `Could not resolve host`, so deployed backend/CDN validation remains blocked on a resolvable HTTPS API base URL.
- Rechecked again on 2026-06-15 with escalated `curl -sS -D - -o /private/tmp/petmagic-api-template-feed-probe.json --max-time 15 'https://api.petmagic.app/api/templates/feed?take=1'`: host resolution still fails with `Could not resolve host: api.petmagic.app`.
- Current device availability check on 2026-06-15 found Android emulator `emulator-5554`, iOS simulator `F18FB7FC-73CC-410D-9EB2-821BEC075E20`, macOS, and Chrome; no wireless/physical device was connected for weak-device FPS/RAM validation.

Gallery cross-flow scenario:

- Opens My Pets and enters a pet detail screen.
- Uses a selected pet photo for generation.
- Verifies generation start receives `petId=pet-42` and `petPhotoId=photo-7`.
- Routes through Generation Status.
- Opens Creations and verifies the completed generated result appears.
- Saves and shares the completed Ready-card media through injected media actions, opens the completed result from the Ready-card action sheet, verifies `markRead`, returns to Creations, deletes the result, and verifies the item is removed from the gallery state.

Current cross-flow runner evidence after the Pet Photos action-state reset:

- iOS simulator artifact `artifacts/mobile-template-feed/ios-simulator-gallery-cross-flow-current-debug-20260615T070421Z` passed with exit code 0, `completion_marker: all_tests_passed_log`, `driver_request_result: true`, `integration_response_data: present`, and `max_cache_kb: 928`.
- Android profile artifact `artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-current-profile-20260615T070619Z` passed with exit code 0, `completion_marker: all_tests_passed_log`, `driver_request_result: true`, `integration_response_data: present`, `max_total_pss_kb: 169738`, `max_total_rss_kb: 251960`, and `max_private_cache_kb: 160`.
- Android profile GSM artifact `artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-current-gsm-20260615T070733Z` passed with exit code 0, `completion_marker: all_tests_passed_log`, `driver_request_result: true`, `integration_response_data: present`, `max_total_pss_kb: 168148`, `max_total_rss_kb: 253308`, and `max_private_cache_kb: 160`; emulator network status after shaping reported 14400 bits/s download and upload, and the runner reset network speed after completion.
- Direct rerun after local artifact cleanup scheduling: `flutter test -d emulator-5554 integration_test/gallery_cross_flow_test.dart --reporter=compact` passed on Android emulator with `1 passed`.
- Direct rerun after local artifact cleanup scheduling: `flutter test -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 integration_test/gallery_cross_flow_test.dart --reporter=compact` passed on iOS simulator with `1 passed`.

Profile response summary from `build/integration_response_data.json`:

```text
frame_count: 128
average_frame_build_time_millis: 2.434
90th_percentile_frame_build_time_millis: 3.952
99th_percentile_frame_build_time_millis: 7.155
worst_frame_build_time_millis: 9.027
missed_frame_build_budget_count: 0
average_frame_rasterizer_time_millis: 67.213
90th_percentile_frame_rasterizer_time_millis: 71.451
99th_percentile_frame_rasterizer_time_millis: 94.569
worst_frame_rasterizer_time_millis: 101.994
missed_frame_rasterizer_budget_count: 127
new_gen_gc_count: 44
old_gen_gc_count: 28
average_picture_cache_memory: 0.0
worst_picture_cache_memory: 0.0
```

Interpretation:

- The Dart/UI build budget is healthy in profile mode for the 1005-item lazy feed smoke.
- Rasterizer timings on this Android emulator are not acceptable as proof of production smoothness; the emulator consistently reports slow raster frames. Treat physical-device profiling as still required.

Sampled runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-sampled-20260614T230942Z
```

Sampled runner summary:

```text
exit_code: 0
frame_count: 128
average_frame_build_time_millis: 3.710
90th_percentile_frame_build_time_millis: 7.679
99th_percentile_frame_build_time_millis: 18.214
worst_frame_build_time_millis: 35.438
missed_frame_build_budget_count: 3
average_frame_rasterizer_time_millis: 87.466
90th_percentile_frame_rasterizer_time_millis: 117.479
missed_frame_rasterizer_budget_count: 127
peak_total_pss_kb: 189931
private_cache_peak_kb: 168
```

The runner captured live Android `dumpsys meminfo` samples during the app process. Samples started after install/startup; early `during-01..03` files correctly show no process yet, while `during-04..08` contain `com.petmagic.app` memory data.

Slow-network emulator runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-gsm-20260614T231225Z
```

Slow-network runner summary:

```text
exit_code: 0
network_speed_command: OK
frame_count: 128
average_frame_build_time_millis: 3.494
90th_percentile_frame_build_time_millis: 6.431
99th_percentile_frame_build_time_millis: 14.792
worst_frame_build_time_millis: 18.088
missed_frame_build_budget_count: 1
average_frame_rasterizer_time_millis: 92.447
90th_percentile_frame_rasterizer_time_millis: 136.352
missed_frame_rasterizer_budget_count: 127
peak_total_pss_kb: 191002
private_cache_peak_kb: 168
```

Backend-backed runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-backend-stress-controller-search-20260614T234931Z
```

Backend-backed runner summary:

```text
exit_code: 0
target: integration_test/templates_feed_backend_stress_test.dart
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
frame_count: 84
average_frame_build_time_millis: 3.320
90th_percentile_frame_build_time_millis: 5.476
99th_percentile_frame_build_time_millis: 16.443
worst_frame_build_time_millis: 17.311
missed_frame_build_budget_count: 2
peak_total_pss_kb: 181111
peak_total_rss_kb: 265460
private_cache_peak_kb: 144
workflow_feed_request_count: 10
workflow_used_cursor_page: true
workflow_page_query_count: 0
workflow_search_requests: cat,dog
workflow_cancelled_searches: cat
workflow_final_item_ids: dog-template-000,dog-template-001,dog-template-002
```

The QA runner now sets `FLUTTER_TEST_OUTPUTS_DIR` to the run directory, writes `completion-summary.json`, and copies `flutter_driver_commands_*.log` when present, so driver `request_data` evidence can be audited even if the response JSON is absent.

Important limitation: `templates_feed_stress_test.dart` uses an overridden in-memory templates controller, so this `NETWORK_SPEED=gsm` run validates the 1005-item UI stress harness and runner network shaping path, but it does not prove backend/API behavior under slow mobile internet. Backend-backed slow-network feed/search pagination remains required.

Backend-backed slow-network runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-backend-gsm-20260614T234818Z
```

Backend-backed slow-network runner summary:

```text
exit_code: 0
network_speed_command: OK
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
frame_count: 82
average_frame_build_time_millis: 2.919
90th_percentile_frame_build_time_millis: 5.184
99th_percentile_frame_build_time_millis: 9.977
worst_frame_build_time_millis: 14.220
missed_frame_build_budget_count: 0
average_frame_rasterizer_time_millis: 65.468
90th_percentile_frame_rasterizer_time_millis: 79.398
missed_frame_rasterizer_budget_count: 78
peak_total_pss_kb: 176532
peak_total_rss_kb: 260960
private_cache_peak_kb: 144
workflow_feed_request_count: 10
workflow_used_cursor_page: true
workflow_page_query_count: 0
workflow_search_requests: cat,dog
workflow_cancelled_searches: cat
workflow_final_item_ids: dog-template-000,dog-template-001,dog-template-002
```

This run validates the mobile real-controller/real-data-source path with a fake in-process Dio backend while the emulator network is shaped to GSM. Because the adapter is not a real HTTP backend, true backend/API slow-network latency remains a required external/integration environment check.

Backend-backed Android long-session runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-backend-long-session-cache-budget-20260615T023013Z
```

Backend-backed Android long-session summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
workflow_feed_request_count: 10
workflow_used_cursor_page: true
workflow_page_query_count: 0
workflow_cancelled_searches: cat
long_session_cycles: 12
long_session_request_count_delta: 24
long_session_feed_request_count: 34
long_session_duplicate_adjacent_query_count: 0
long_session_page_query_count: 0
long_session_cursor_query_count: 12
long_session_search_query_count: 24
long_session_max_loaded_item_count: 40
long_session_max_visible_card_count: 8
long_session_max_cache_query_key_count: 6
long_session_max_duplicate_item_count: 0
long_session_final_cache_query_key_count: 6
long_session_final_loaded_item_count: 40
long_session_final_query: type=Image, category=Search, search=loop11
long_session_frame_count: 48
long_session_average_frame_build_time_millis: 8.372
long_session_90th_percentile_frame_build_time_millis: 12.746
long_session_worst_frame_build_time_millis: 26.036
long_session_missed_frame_build_budget_count: 2
peak_total_pss_kb: 189846
peak_total_rss_kb: 267804
private_cache_peak_kb: 144
```

The long-session emulator run adds stronger automated evidence for repeated use after thumbnail byte-budget cleanup, request deduplication, cursor pagination, bounded visible cards, bounded in-memory query cache, and no duplicate visible items. Rasterizer timings on this emulator remain unsuitable for production FPS claims; physical-device profiling is still required.

Real-HTTP Android profile runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-http-cache-budget-profile-20260615T021939Z
```

Real-HTTP Android profile summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
request_count: 8
request_paths: /api/templates/feed?take=20, /media/template-thumb.png, cursor=cursor-20, cursor=cursor-40, cursor=cursor-60, type=Video, type=Video&category=Search, search=cat, search=dog
used_cursor_page: true
page_query_count: 0
cursor_query_count: 3
search_requests: cat,dog
completed_searches: dog,cat
media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}
thumbnail_request_count: 1
video_preview_request_count: 1
final_query: type=Video, category=Search, search=dog
final_item_ids: dog-template-000,dog-template-001,dog-template-002
duplicate_item_count: 0
visible_card_count: 3
frame_count: 63
average_frame_build_time_millis: 4.347
90th_percentile_frame_build_time_millis: 7.457
worst_frame_build_time_millis: 14.692
missed_frame_build_budget_count: 0
average_frame_rasterizer_time_millis: 73.532
missed_frame_rasterizer_budget_count: 59
peak_total_pss_kb: 193347
peak_total_rss_kb: 272024
private_cache_peak_kb: 184
```

This run closes the gap between the fake Dio adapter stress test and the normal Dio HTTP client path on Android profile after thumbnail byte-budget cleanup, adds device-level media request counting for card thumbnails and video previews, and proves one shared thumbnail URL plus one shared video preview URL are not redownloaded across video filter, category, stale search, and latest search rendering. It still uses an in-process local HTTP server rather than the deployed backend, so true external backend/API latency and physical video playback profiling remain separate QA requirements.

Real-HTTP Android profile rerun with valid MP4 preview fixture artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-http-valid-video-20260615
```

Real-HTTP Android valid-video profile summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
request_count: 8
used_cursor_page: true
page_query_count: 0
cursor_query_count: 3
search_requests: cat,dog
completed_searches: dog,cat
media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}
thumbnail_request_count: 1
video_preview_request_count: 1
final_query: type=Video, category=Search, search=dog
final_item_ids: dog-template-000,dog-template-001,dog-template-002
duplicate_item_count: 0
visible_card_count: 3
frame_count: 65
average_frame_build_time_millis: 4.854
90th_percentile_frame_build_time_millis: 8.584
worst_frame_build_time_millis: 27.539
missed_frame_build_budget_count: 3
average_frame_rasterizer_time_millis: 71.978
missed_frame_rasterizer_budget_count: 59
peak_total_pss_kb: 195202
peak_total_rss_kb: 281296
private_cache_peak_kb: 188
log_video_error_markers: none for UnrecognizedInputFormatException, ExoPlaybackException, NoDeclaredBrand, video source errors
```

This rerun replaces the earlier weak local-video fixture evidence. The previous fixture only returned an MP4 brand header, so ExoPlayer correctly logged format-sniffing failures even though request counting passed. The valid-video rerun keeps the one-thumbnail/one-video-download assertion intact and removes those decoder/source errors from the Android profile log. Emulator rasterizer timings remain non-production FPS evidence.

Real-HTTP Android profile GSM rerun with valid MP4 preview fixture artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-http-valid-video-gsm-20260615
```

Real-HTTP Android valid-video GSM profile summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
network_speed_command: OK
request_count: 8
used_cursor_page: true
page_query_count: 0
cursor_query_count: 3
search_requests: cat,dog
completed_searches: dog,cat
media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}
thumbnail_request_count: 1
video_preview_request_count: 1
final_query: type=Video, category=Search, search=dog
final_item_ids: dog-template-000,dog-template-001,dog-template-002
duplicate_item_count: 0
visible_card_count: 3
frame_count: 62
average_frame_build_time_millis: 5.084
90th_percentile_frame_build_time_millis: 10.548
worst_frame_build_time_millis: 25.896
missed_frame_build_budget_count: 2
average_frame_rasterizer_time_millis: 77.178
missed_frame_rasterizer_budget_count: 55
peak_total_pss_kb: 199523
peak_total_rss_kb: 286268
private_cache_peak_kb: 188
log_playback_exception_markers: none for UnrecognizedInputFormatException, ExoPlaybackException, NoDeclaredBrand, Video player errors, parser/source errors, or renderer errors
```

This GSM rerun keeps the local slow-network real-HTTP evidence aligned with the valid-video fixture. The Android emulator still emits low-level `CCodecConfig`/`Codec2Client` debug lines during video initialization; these are retained in the raw log and are not treated as production playback/FPS evidence. No ExoPlayer/source/playback exception markers were present.

Real-HTTP Android profile rerun with backend random endpoint artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-http-random-modes-20260615
```

Real-HTTP Android random endpoint profile summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
request_count: 8
used_cursor_page: true
page_query_count: 0
cursor_query_count: 3
search_requests: cat,dog
completed_searches: dog,cat
random_request_count: 3
random_queries: {'category': 'Search', 'includePremium': 'true'}, {'type': 'Image', 'category': 'Search', 'includePremium': 'false'}, {'type': 'Video', 'category': 'Search', 'includePremium': 'false'}
random_template_ids: random-any-search-template,random-image-search-template,random-video-search-template
request_paths_includes: /api/templates/random?category=Search&includePremium=true, /api/templates/random?type=Image&category=Search&includePremium=false, /api/templates/random?type=Video&category=Search&includePremium=false
media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}
thumbnail_request_count: 1
video_preview_request_count: 1
final_query: type=Video, category=Search, search=dog
final_item_ids: dog-template-000,dog-template-001,dog-template-002
duplicate_item_count: 0
frame_count: 63
average_frame_build_time_millis: 5.332
90th_percentile_frame_build_time_millis: 8.248
worst_frame_build_time_millis: 66.974
missed_frame_build_budget_count: 3
average_frame_rasterizer_time_millis: 72.544
missed_frame_rasterizer_budget_count: 60
peak_total_pss_kb: 205835
peak_total_rss_kb: 291136
private_cache_peak_kb: 188
log_playback_exception_markers: none for UnrecognizedInputFormatException, ExoPlaybackException, NoDeclaredBrand, Video player errors, parser/source errors, or renderer errors
```

This run extends the real-HTTP device smoke beyond feed pagination/search/media caching: the mobile repository/data-source path requests random templates from the backend for all/image/video modes using the active category and premium flag. The returned random template ids are intentionally outside the already loaded feed ids, proving the mobile path does not select random templates from only visible or already loaded cards.

Real-HTTP Android profile rerun with type transition cache isolation artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-http-type-transitions-20260615
```

Real-HTTP Android type transition profile summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
request_count: 9
used_cursor_page: true
page_query_count: 0
cursor_query_count: 3
search_requests: cat,dog
completed_searches: dog,cat
random_request_count: 3
request_paths: /api/templates/feed?take=20, /media/template-thumb.png, /api/templates/feed?cursor=cursor-20&take=20, /api/templates/feed?cursor=cursor-40&take=20, /api/templates/feed?cursor=cursor-60&take=20, /api/templates/feed?type=Video&take=20, /media/template-video-preview.mp4, /api/templates/feed?type=Image&take=20, /api/templates/feed?type=Video&category=Search&take=20, /api/templates/feed?type=Video&category=Search&search=cat&take=20, /api/templates/feed?type=Video&category=Search&search=dog&take=20, /api/templates/random?category=Search&includePremium=true, /api/templates/random?type=Image&category=Search&includePremium=false, /api/templates/random?type=Video&category=Search&includePremium=false
media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}
thumbnail_request_count: 1
video_preview_request_count: 1
final_query: type=Video, category=Search, search=dog
final_item_ids: dog-template-000,dog-template-001,dog-template-002
duplicate_item_count: 0
frame_count: 70
average_frame_build_time_millis: 6.516
90th_percentile_frame_build_time_millis: 13.879
worst_frame_build_time_millis: 47.348
missed_frame_build_budget_count: 6
average_frame_rasterizer_time_millis: 87.557
missed_frame_rasterizer_budget_count: 61
peak_total_pss_kb: 209247
peak_total_rss_kb: 295208
private_cache_peak_kb: 196
log_playback_exception_markers: none for UnrecognizedInputFormatException, ExoPlaybackException, NoDeclaredBrand, Video player errors, parser/source errors, or renderer errors
```

This run pins the real-HTTP type-transition behavior to the intended request economy: `All` is already represented by the initial `/api/templates/feed?take=20` query without a `type` parameter, returning to `All` after `Video` uses the cached all-feed page without an extra backend call, switching to `Image` issues exactly one `type=Image` feed query with no stale video cards, and returning to `Video` reuses the cached video feed before the category/search workflow continues. Emulator rasterizer timings remain non-production FPS evidence.

Real-HTTP Android profile rerun after deferred video initialize-dispose fix artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-http-network-bytes-post-video-dispose-fix-20260615T122500Z
```

Real-HTTP Android post-fix profile summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
request_count: 9
used_cursor_page: true
page_query_count: 0
cursor_query_count: 3
search_requests: cat,dog
completed_searches: dog,cat
random_request_count: 3
media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}
thumbnail_request_count: 1
video_preview_request_count: 1
final_query: type=Video, category=Search, search=dog
final_item_ids: dog-template-000,dog-template-001,dog-template-002
duplicate_item_count: 0
frame_count: 68
average_frame_build_time_millis: 16.973
90th_percentile_frame_build_time_millis: 48.638
worst_frame_build_time_millis: 107.041
missed_frame_build_budget_count: 14
average_frame_rasterizer_time_millis: 150.398
missed_frame_rasterizer_budget_count: 64
peak_total_pss_kb: 204395
peak_total_rss_kb: 274356
private_cache_peak_kb: 196
network_app_uid: 10299
network_rx_bytes_delta: 0
network_tx_bytes_delta: 0
network_xt_qtaguid_rows: 0 on local-loopback samples
log_playback_exception_markers: none for UnrecognizedInputFormatException, ExoPlaybackException, NoDeclaredBrand, Video player errors, MediaCodecVideoRenderer error, released-surface errors, source errors, Playback error, or PlatformException
```

The immediately preceding post-network-counter run exposed the Android video lifecycle race as `MediaCodecVideoRenderer error` / `surface has been released` while the test still passed. `TemplateCard` now defers disposing stale native video controllers until `VideoPlayerController.initialize()` completes. The post-fix profile rerun above keeps the one-thumbnail/one-video-download contract and the log scan is clean for playback/decoder/source markers. The UID network snapshot path is present, but this local in-app `127.0.0.1` HTTP fixture produced `xt_qtaguid_rows=0` and zero RX/TX bytes, so deployed backend/CDN byte accounting remains separate required QA.

Real-HTTP Android profile rerun with runner-enforced video log scan and dispose-safe random cancellation artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-http-logscan-post-random-dispose-fix-final-20260615T132000Z
```

Real-HTTP Android log-scan profile summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
video_playback_log_marker_count: 0
request_count: 9
used_cursor_page: true
page_query_count: 0
cursor_query_count: 3
search_requests: cat,dog
random_request_count: 3
media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}
thumbnail_request_count: 1
video_preview_request_count: 1
duplicate_item_count: 0
final_query: type=Video, category=Search, search=dog
final_item_ids: dog-template-000,dog-template-001,dog-template-002
frame_count: 69
average_frame_build_time_millis: 7.555
90th_percentile_frame_build_time_millis: 16.898
worst_frame_build_time_millis: 128.790
missed_frame_build_budget_count: 9
average_frame_rasterizer_time_millis: 70.317
missed_frame_rasterizer_budget_count: 58
peak_total_pss_kb: 201071
peak_total_rss_kb: 278064
private_cache_peak_kb: 216
network_app_uid: 10301
network_rx_bytes_delta: 0
network_tx_bytes_delta: 0
```

This run verifies the QA runner's new `video-playback-log-summary.*` artifacts end to end. `completion-summary.json` now records `video_playback_log_failed` and `video_playback_log_marker_count`; future runs fail if critical video markers such as `ExoPlaybackException`, `MediaCodecVideoRenderer error`, released-surface errors, source errors, `VideoError`, or AVPlayer failures appear even when the Flutter test response is otherwise green. The final run also proves the random-template dispose path no longer triggers Riverpod's unsafe `ref` read during unmount.

Real-HTTP Android profile GSM runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-http-cache-budget-gsm-20260615T022056Z
```

Real-HTTP Android profile GSM summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
network_speed_command: OK
network_status_after_set: download/upload 14400 bits/s
network_status_after_reset: full speed
request_count: 8
used_cursor_page: true
page_query_count: 0
cursor_query_count: 3
search_requests: cat,dog
media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}
thumbnail_request_count: 1
video_preview_request_count: 1
final_query: type=Video, category=Search, search=dog
final_item_ids: dog-template-000,dog-template-001,dog-template-002
duplicate_item_count: 0
frame_count: 66
average_frame_build_time_millis: 4.988
90th_percentile_frame_build_time_millis: 9.121
worst_frame_build_time_millis: 17.089
missed_frame_build_budget_count: 2
average_frame_rasterizer_time_millis: 72.701
missed_frame_rasterizer_budget_count: 63
peak_total_pss_kb: 192495
peak_total_rss_kb: 272204
private_cache_peak_kb: 184
```

This run validates the real Dio/default HTTP adapter path under Android emulator GSM network shaping while preserving cursor pagination, filter/search isolation, one shared thumbnail download, and one shared video preview download. It still uses a local in-process HTTP server, so deployed backend/CDN slow-network behavior remains a required external QA item.

Earlier backend-backed Android profile stress harness fixes:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-backend-stress-20260614T232853Z
artifacts/mobile-template-feed/android-emulator-template-feed-backend-stress-20260614T233151Z
artifacts/mobile-template-feed/android-emulator-template-feed-backend-stress-20260614T233403Z
artifacts/mobile-template-feed/android-emulator-template-feed-backend-stress-diagnostic-20260614T234651Z
```

- The first `integration_test/templates_feed_backend_stress_test.dart` run failed waiting for the cursor pagination condition after the first scroll/load-more step.
- The test harness was tightened to drive the `TemplatesPage` `CustomScrollView.controller` instead of a generic `Scrollable`, and the pagination wait now accepts `>= 40` loaded items because fast flings can legitimately prefetch more than one cursor page.
- The later `android-emulator-template-feed-backend-stress-20260614T233403Z` runner returned `exit_code: 0`, but did not produce completion-marker or response-data evidence.
- The diagnostic run showed profile-device text entry did not trigger the debounced search (`query.search` stayed null), so backend stress now drives search through `TemplatesController.setSearch`; UI search debounce remains covered by widget tests.
- The test driver was then changed to write response data directly into `FLUTTER_TEST_OUTPUTS_DIR`, and the `android-emulator-template-feed-backend-stress-controller-search-20260614T234931Z` plus `android-emulator-template-feed-backend-gsm-20260614T234818Z` runs produced request-count and workflow evidence. Real HTTP backend slow-network and physical-device FPS proof remain required.

Latest gallery cross-flow runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-production-safe-profile-20260615T022457Z
```

Latest gallery cross-flow metrics summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
max_total_pss_kb: 169135
max_total_rss_kb: 249992
max_private_cache_kb: 152
max_external_cache_kb: None
flutter_drive_log: All tests passed
note: integration_response_data.json is present for driver auditing but contains null for this scenario; runner metrics come from Android samples.
```

This latest cross-flow profile run uses `cdn.petmagic.app` media fixtures so the save/share path is exercised under the same non-debug generation media allowlist used by profile builds. Earlier `.test` CDN fixtures passed debug integration tests but were correctly rejected by `parseSafeGenerationMediaUri` in profile mode.

The Android `dumpsys gfxinfo` samples for this cross-flow run reported only one native frame in each sampled bucket, so they are retained as artifacts but not used as production FPS evidence.

Gallery cross-flow GSM runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-production-safe-gsm-20260615T023728Z
```

Gallery cross-flow GSM summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
network_speed_command: OK
network_status_after_set: download/upload 14400 bits/s
network_status_after_reset: full speed
max_total_pss_kb: 169932
max_total_rss_kb: 248616
max_private_cache_kb: 160
max_external_cache_kb: None
```

This run validates the Pet Photos -> Templates -> Generation Status -> Creations smoke under Android emulator GSM network shaping with production-safe media fixtures. It still uses test doubles for the gallery/generation backend path, so it is not evidence for deployed backend/CDN slow-network latency.

Runner output-directory validation artifacts:

```text
artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-profile-outputdir-20260614T234146Z
```

Runner output-directory validation summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
max_total_pss_kb: 161450
max_total_rss_kb: 245328
max_private_cache_kb: 152
```

Latest 1005-item stress runner artifacts:

```text
artifacts/mobile-template-feed/android-emulator-template-feed-stress-profile-20260614T232003Z
```

Latest 1005-item stress metrics summary:

```text
exit_code: 0
frame_count: 130
average_frame_build_time_millis: 2.570
90th_percentile_frame_build_time_millis: 4.413
99th_percentile_frame_build_time_millis: 6.632
worst_frame_build_time_millis: 7.295
missed_frame_build_budget_count: 0
average_frame_rasterizer_time_millis: 70.966
90th_percentile_frame_rasterizer_time_millis: 81.620
99th_percentile_frame_rasterizer_time_millis: 129.285
worst_frame_rasterizer_time_millis: 134.755
missed_frame_rasterizer_budget_count: 129
max_total_pss_kb: 183434
max_total_rss_kb: 266668
max_private_cache_kb: 144
```

The Android `dumpsys gfxinfo` samples report only one native frame in these Flutter profile runs and can emit platform dump warnings. Treat `integration_response_data.json` as the stronger emulator frame-timing evidence; physical-device profiling is still required for production FPS claims.

## Device QA Runner

Script added:

```sh
scripts/qa/run-template-feed-device-qa.sh
```

Example runs:

```sh
DEVICE_ID=emulator-5554 MODE=profile scripts/qa/run-template-feed-device-qa.sh
DEVICE_ID=emulator-5554 MODE=profile NETWORK_SPEED=gsm scripts/qa/run-template-feed-device-qa.sh
DEVICE_ID=<physical-ios-device-id> MODE=profile scripts/qa/run-template-feed-device-qa.sh
flutter test -d emulator-5554 integration_test/templates_external_backend_smoke_test.dart --dart-define=PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL=https://<deployed-api-host> --dart-define=PETMAGIC_SKIP_FIREBASE=true
RUN_ID=android-template-feed-external-api DEVICE_ID=emulator-5554 MODE=debug TARGET=integration_test/templates_external_backend_smoke_test.dart FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL=https://<deployed-api-host> --dart-define=PETMAGIC_SKIP_FIREBASE=true' scripts/qa/run-template-feed-device-qa.sh
```

The script writes artifacts under `artifacts/mobile-template-feed/<run-id>/`, including:

- `flutter-drive.log`
- `completion-summary.json` with exit code, completion marker, driver request result, response-data presence, video playback log marker status, and cache-budget status
- `integration_response_data.json` when Flutter emits it; the runner now sets `FLUTTER_TEST_OUTPUTS_DIR` so the test driver writes it directly into the run directory
- `flutter_driver_commands_*.log`, when present
- `flutter-devices.txt` and `flutter-doctor.txt`
- `metrics-summary.json` and `metrics-summary.md`
- `video-playback-log-summary.json` and `video-playback-log-summary.md`; nonzero critical playback/source markers make the runner fail even if `flutter drive` otherwise reports a green response
- `cache-budget-summary.json` and `cache-budget-summary.md`; nonzero cache-delta violations make the runner fail even if `flutter drive` otherwise reports a green response
- Android `dumpsys meminfo`
- Android `dumpsys gfxinfo ... framestats`
- Android private/external cache `du` snapshots when accessible. Private app snapshots intentionally measure the app `cache` directory only, not `files/app_flutter` extracted assets.
- Android per-app UID network snapshots (`android-network-uid-<phase>.txt`) with qtaguid RX/TX byte counters when the platform exposes them
- during-run Android samples at `ANDROID_SAMPLE_INTERVAL_SECONDS` intervals
- optional Android emulator network speed capture/reset when `NETWORK_SPEED` is set
- Android emulator network status snapshots before shaping, after shaping, and after reset
- iOS Simulator app-container cache snapshots when the target is a simulator
- optional extra Flutter drive args through `FLUTTER_DRIVE_EXTRA_ARGS`
- cache-delta thresholds through `QA_MAX_ANDROID_PRIVATE_CACHE_DELTA_KB`, `QA_MAX_ANDROID_EXTERNAL_CACHE_DELTA_KB`, and `QA_MAX_IOS_SIMULATOR_CACHE_DELTA_KB`; defaults are `65536` KB each, and values `<= 0` disable the corresponding threshold
- scalar/list/dict `integration_response_data` workflow counters in `metrics-summary.json`; the runner script now also emits those under `Flutter Report Data` in future `metrics-summary.md` files
- raw non-frame `integration_response_data` under `flutter_report_data_raw` in `metrics-summary.json`, so nested probe data is preserved for audit
- a compact `External Backend Smoke` section in `metrics-summary.md` and `metrics-summary.json` when `templates_external_backend_smoke` report data is present, including stage/reason, selected category/search, request count, feed probes, and random probes
- iOS Simulator SPM deployment target normalization to 15.0 before and during `flutter drive --no-pub`, explicit `xcodebuild -resolvePackageDependencies`, stale app termination before drive, and build-failure log detection plus stale response-data cleanup to avoid stale-driver false positives

`bash -n scripts/qa/run-template-feed-device-qa.sh` passes.

Cache-delta gate validation artifact:

```text
artifacts/mobile-template-feed/android-emulator-external-smoke-cache-budget-gate-cacheonly-quoted-20260615T153000Z
```

Cache-delta gate validation summary:

```text
exit_code: 0
completion_marker: all_tests_passed_log
driver_request_result: true
integration_response_data: present
video_playback_log_marker_count: 0
cache_budget_failed: false
cache_budget_violation_count: 0
max_private_cache_kb: 8
private_cache_before_kb: 8
private_cache_after_kb: 8
private_cache_delta_kb: 0
cache_budget_threshold_android_private_cache_delta_kb: 65536
```

The cache snapshot command now quotes the remote Android `run-as ... sh -c` payload and measures only the app `cache` directory. The intermediate `android-emulator-external-smoke-cache-budget-gate-cacheonly-20260615T151500Z` run is not counted as passing evidence because it exposed the previous measurement bug: `du` was effectively run over the whole app data directory and included `files/app_flutter/flutter_assets`, producing a false cache-delta violation.

## iOS Simulator Status

Available device:

```text
iPhone 16 - F18FB7FC-73CC-410D-9EB2-821BEC075E20 - iOS 18.0 simulator
```

`xcodebuild -resolvePackageDependencies` succeeds and resolves `FlutterFramework`.

Simulator commands:

```sh
flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/templates_feed_stress_test.dart -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 --no-dds
flutter test integration_test/templates_feed_stress_test.dart -d F18FB7FC-73CC-410D-9EB2-821BEC075E20
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/templates_feed_stress_test.dart -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 --no-dds
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/gallery_cross_flow_test.dart -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 --no-dds --host-vmservice-port=61002
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/gallery_cross_flow_test.dart -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 --no-dds --host-vmservice-port=61003 --dart-define=PETMAGIC_SKIP_FIREBASE=true
RUN_ID=ios-simulator-gallery-cross-flow-debug-20260614T231837Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61004 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-backend-debug-20260614T235404Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_backend_stress_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-gallery-cross-flow-save-share-debug-20260615T000712Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61006 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-gallery-cross-flow-production-safe-debug-20260615T024055Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/gallery_cross_flow_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61030 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-backend-debug-20260615T002622Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61008 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-media-filecache-resolve-debug-20260615T011021Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61011 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-video-cache-debug-20260615T015421Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61022 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-cache-budget-debug-retry-20260615T022449Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61031 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-valid-video-20260615 DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-random-modes-20260615 DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-type-transitions-20260615 DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart FLUTTER_DRIVE_EXTRA_ARGS='--dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-logscan-20260615T134000Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61041 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
RUN_ID=ios-simulator-template-feed-http-after-media-cache-20260615T093800Z DEVICE_ID=F18FB7FC-73CC-410D-9EB2-821BEC075E20 MODE=debug TARGET=integration_test/templates_feed_http_backend_smoke_test.dart ANDROID_SAMPLE_INTERVAL_SECONDS=1 FLUTTER_DRIVE_EXTRA_ARGS='--host-vmservice-port=61042 --dart-define=PETMAGIC_SKIP_FIREBASE=true' bash scripts/qa/run-template-feed-device-qa.sh
```

Observed results:

- Local Creations support-context regression on 2026-06-15 passes: ready-card report, failed-card direct support, and failed-card bottom-sheet support now route through `SupportChatPage.routeFor(...)` with a prefilled generation report and `relatedGenerationId`; focused checks covered `generations_gallery_page_test.dart`, support chat route parsing, composer prefill, and first-message `relatedGenerationId` propagation to `openConversation`.
- Local Creations narrow-width premium upsell regression on 2026-06-15 passes: non-premium Creations renders the upsell on a 360px-wide viewport without a `RenderFlex overflow`; the full `generations_gallery_page_test.dart` suite now passes 23/23.
- Local Pet Photos thumbnail-only regression on 2026-06-15 passes: pet photo grid cards now render only safe `thumbnailUrl` values and fall back instead of loading original photo URLs; `my_pets_page_test.dart` covers thumbnails, unsafe URLs, CRUD invalidation, upload cancellation, large lazy grids, and quick-return no-refetch behavior.
- Local Pet Photos to Templates route-preservation regression on 2026-06-15 passes: when Templates opens with `petId` and `petPhotoId`, tapping the already-selected pet shortcut keeps the selected `petPhotoId` before starting generation; focused lifecycle checks confirmed the preserved id reaches `startGenerationFromPet`.
- Local cross-gallery lifecycle rerun on 2026-06-15 passes: `templates_page_lifecycle_test.dart` passes 22/22, including `pet route starts generation with selected pet photo`, `selected pet shortcut preserves selected pet photo`, and `pet photo generation appears in Creations after status route`.
- Local mobile gallery regression suites on 2026-06-15 pass: `generations_gallery_page_test.dart` passes 23/23, `my_pets_page_test.dart` passes 35/35, and `dart analyze` reports no issues for the touched router, support, templates, pets, and test files.
- Local Creations controller/store regression suites on 2026-06-15 pass: `generation_history_controller_test.dart`, `generation_history_controller_lifecycle_test.dart`, and `generation_gallery_store_test.dart` pass 45/45 after the lifecycle static check was aligned with the optimistic-delete contract: tombstone first, mounted guard, server delete, mounted guard, then clear pending server delete.
- Local Creations mapper/API contract regression on 2026-06-15 passes: `generations_gallery_mappers_test.dart` and `template_generation_repository_test.dart` pass 22/22 after generation gallery preview mapping was aligned with `parseSafeGenerationMediaUri`, so unsafe `javascript:`, `data:`, and `file:` media URLs are rejected before image rendering decisions.
- Current device availability on 2026-06-15: `flutter devices` shows Android emulator `emulator-5554`, iOS simulator `F18FB7FC-73CC-410D-9EB2-821BEC075E20`, macOS, and Chrome; no physical or wireless mobile devices are connected.
- Current direct cross-gallery smoke on 2026-06-15 passes on Android emulator: `flutter test -d emulator-5554 integration_test/gallery_cross_flow_test.dart --reporter=compact` passes 1/1.
- Current direct cross-gallery smoke on 2026-06-15 passes on iOS simulator: `flutter test -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 integration_test/gallery_cross_flow_test.dart --reporter=compact` passes 1/1.
- Current post-mapper-hardening direct cross-gallery smoke on 2026-06-15 passes on iOS simulator: `flutter test -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 integration_test/gallery_cross_flow_test.dart --reporter=compact` passes 1/1 after `generations_gallery_mappers.dart` was aligned with safe media URI parsing.
- Current Android profile cross-gallery QA artifact `artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-mapper-safe-profile-20260615-retry` passes with exit code 0, `completion_marker: all_tests_passed_log`, `driver_request_result: true`, `integration_response_data: present`, no video playback/source markers, `max_total_pss_kb: 225034`, `max_total_rss_kb: 298220`, `max_private_cache_kb: 84308`, and app qtaguid RX/TX deltas of 0 for this test-double backend path.
- Current Android GSM profile cross-gallery QA artifact `artifacts/mobile-template-feed/android-emulator-gallery-cross-flow-mapper-safe-gsm-20260615-retry` passes with exit code 0, `completion_marker: all_tests_passed_log`, `driver_request_result: true`, `integration_response_data: present`, no video playback/source markers, `cache_budget_failed: false`, `cache_budget_violation_count: 0`, `max_total_pss_kb: 171838`, `max_total_rss_kb: 252032`, `max_private_cache_kb: 160`, and emulator network shaping confirmed at 14,400 bits/s download/upload before reset.
- Current Android profile preflight artifacts `android-emulator-gallery-cross-flow-mapper-safe-profile-20260615` and `android-emulator-gallery-cross-flow-mapper-safe-gsm-20260615` are not counted as passing evidence: the first failed before Flutter startup on sandbox-denied Flutter cache writes, and the second was superseded by the successful GSM retry above after a transient runner parse failure.
- Current deployed backend availability check on 2026-06-15 remains blocked: `PETMAGIC_EXTERNAL_TEMPLATES_API_BASE_URL` is not set, escalated `nslookup api.petmagic.app` returns NXDOMAIN, and escalated quoted `curl -I --max-time 10 'https://api.petmagic.app/api/templates/feed?take=1'` returns `Could not resolve host: api.petmagic.app`.
- `gallery_cross_flow_test.dart` passes on the iOS 18.0 simulator in debug mode with `PETMAGIC_SKIP_FIREBASE=true`.
- The current `flutter test -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 integration_test/gallery_cross_flow_test.dart --reporter=compact` rerun passes after the cross-flow fixture was moved from `.test` media URLs to `cdn.petmagic.app`.
- Runner artifact `artifacts/mobile-template-feed/ios-simulator-gallery-cross-flow-debug-20260614T231837Z` passes with exit code 0 and records `max_cache_kb: 928` from the simulator app container.
- Updated save/share gallery cross-flow artifact `artifacts/mobile-template-feed/ios-simulator-gallery-cross-flow-save-share-debug-20260615T000712Z` passes with exit code 0, `completion_marker: all_tests_passed_log`, `driver_request_result: true`, `integration_response_data: present`, and `max_cache_kb: 928`.
- Production-safe CDN gallery cross-flow runner artifact `artifacts/mobile-template-feed/ios-simulator-gallery-cross-flow-production-safe-debug-20260615T024055Z` passes with exit code 0, `completion_marker: all_tests_passed_log`, `driver_request_result: true`, `integration_response_data: present`, and `max_cache_kb: 928`.
- Backend-backed template feed runner artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-backend-debug-20260614T235404Z` passes with exit code 0, `completion_marker: all_tests_passed_log`, `driver_request_result: true`, and `integration_response_data: present`.
- iOS simulator backend workflow evidence: `feed_request_count: 11`, `workflow_used_cursor_page: true`, `workflow_page_query_count: 0`, `workflow_search_requests: cat,dog`, `workflow_cancelled_searches: cat`, and final item ids `dog-template-000,dog-template-001,dog-template-002`.
- iOS simulator debug performance/cache summary for the backend-backed run: `frame_count: 156`, `average_frame_build_time_millis: 7.763`, `90th_percentile_frame_build_time_millis: 16.300`, `missed_frame_build_budget_count: 16`, `average_frame_rasterizer_time_millis: 4.144`, `missed_frame_rasterizer_budget_count: 0`, and `max_cache_kb: 928`.
- Previous real-HTTP template feed runner artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-http-cache-budget-debug-retry-20260615T022449Z` passes with exit code 0, `completion_marker: all_tests_passed_log`, `build_failure_marker: false`, `driver_request_result: true`, and `integration_response_data: present`.
- Previous iOS simulator real-HTTP workflow evidence after thumbnail byte-budget cleanup: default Dio HTTP adapter talking to local `127.0.0.1` `HttpServer`, `request_count: 9`, `used_cursor_page: true`, `page_query_count: 0`, `cursor_query_count: 4`, `search_requests: cat,dog`, `completed_searches: dog,cat`, `media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}`, `thumbnail_request_count: 1`, `video_preview_request_count: 1`, final query `type=Video, category=Search, search=dog`, final item ids `dog-template-000,dog-template-001,dog-template-002`, and `duplicate_item_count: 0`.
- Previous iOS simulator real-HTTP debug performance/cache summary after thumbnail byte-budget cleanup: `frame_count: 100`, `average_frame_build_time_millis: 14.668`, `90th_percentile_frame_build_time_millis: 35.930`, `missed_frame_build_budget_count: 29`, `average_frame_rasterizer_time_millis: 5.165`, `missed_frame_rasterizer_budget_count: 0`, and `max_cache_kb: 936`.
- Latest real-HTTP template feed runner artifact with the valid MP4 preview fixture `artifacts/mobile-template-feed/ios-simulator-template-feed-http-valid-video-20260615` passes with exit code 0, `completion_marker: all_tests_passed_log`, `build_failure_marker: false`, `driver_request_result: true`, and `integration_response_data: present`.
- Latest iOS simulator valid-video real-HTTP workflow evidence: `request_count: 9`, `used_cursor_page: true`, `page_query_count: 0`, `cursor_query_count: 4`, `search_requests: cat,dog`, `completed_searches: dog,cat`, `media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}`, `thumbnail_request_count: 1`, `video_preview_request_count: 1`, final query `type=Video, category=Search, search=dog`, final item ids `dog-template-000,dog-template-001,dog-template-002`, and `duplicate_item_count: 0`.
- Latest iOS simulator valid-video debug performance/cache summary: `frame_count: 107`, `average_frame_build_time_millis: 13.024`, `90th_percentile_frame_build_time_millis: 32.108`, `missed_frame_build_budget_count: 24`, `average_frame_rasterizer_time_millis: 5.451`, `missed_frame_rasterizer_budget_count: 1`, and `max_cache_kb: 940`.
- Latest iOS simulator valid-video `flutter-drive.log` has no `AVPlayer`, `Video player had error`, `PlatformException`, source-error, or failed-video markers.
- Latest iOS simulator random-modes real-HTTP artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-http-random-modes-20260615` passes with exit code 0, `completion_marker: all_tests_passed_log`, `build_failure_marker: false`, `driver_request_result: true`, and `integration_response_data: present`.
- Latest iOS simulator random-modes workflow evidence: `random_request_count: 3`, random queries `{category=Search, includePremium=true}`, `{type=Image, category=Search, includePremium=false}`, `{type=Video, category=Search, includePremium=false}`, random ids `random-any-search-template,random-image-search-template,random-video-search-template`, `thumbnail_request_count: 1`, `video_preview_request_count: 1`, final feed ids `dog-template-000,dog-template-001,dog-template-002`, and `duplicate_item_count: 0`.
- Latest iOS simulator random-modes debug performance/cache summary: `frame_count: 98`, `average_frame_build_time_millis: 14.236`, `90th_percentile_frame_build_time_millis: 29.233`, `missed_frame_build_budget_count: 28`, `average_frame_rasterizer_time_millis: 5.490`, `missed_frame_rasterizer_budget_count: 1`, and `max_cache_kb: 940`.
- Latest iOS simulator random-modes `flutter-drive.log` has no `AVPlayer`, `Video player had error`, `PlatformException`, source-error, parser, or renderer error markers.
- Latest iOS simulator type-transition real-HTTP artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-http-type-transitions-20260615` passes with exit code 0, `completion_marker: all_tests_passed_log`, `build_failure_marker: false`, `driver_request_result: true`, and `integration_response_data: present`.
- Latest iOS simulator type-transition workflow evidence: `request_count: 10`, `used_cursor_page: true`, `page_query_count: 0`, `cursor_query_count: 4`, `request_paths` include the initial all feed without `type`, `/api/templates/feed?type=Video&take=20`, `/api/templates/feed?type=Image&take=20`, category/search video feed queries, and all/image/video random endpoint calls; `thumbnail_request_count: 1`, `video_preview_request_count: 1`, final feed ids `dog-template-000,dog-template-001,dog-template-002`, and `duplicate_item_count: 0`.
- Latest iOS simulator type-transition debug performance/cache summary: `frame_count: 101`, `average_frame_build_time_millis: 16.304`, `90th_percentile_frame_build_time_millis: 37.297`, `missed_frame_build_budget_count: 37`, `average_frame_rasterizer_time_millis: 5.621`, `missed_frame_rasterizer_budget_count: 1`, and `max_cache_kb: 940`.
- Latest iOS simulator type-transition `flutter-drive.log` has no `AVPlayer`, `Video player had error`, `PlatformException`, source-error, parser, renderer, or generic failure markers.
- Latest iOS simulator log-scan real-HTTP artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-http-logscan-20260615T134000Z` passes with exit code 0, `completion_marker: all_tests_passed_log`, `build_failure_marker: false`, `driver_request_result: true`, `integration_response_data: present`, `video_playback_log_failed: false`, and `video_playback_log_marker_count: 0`.
- Latest iOS simulator log-scan workflow evidence: `request_count: 10`, `used_cursor_page: true`, `page_query_count: 0`, `cursor_query_count: 4`, `search_requests: cat,dog`, `completed_searches: dog,cat`, `random_request_count: 3`, `random_template_ids: random-any-search-template,random-image-search-template,random-video-search-template`, `media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}`, `thumbnail_request_count: 1`, `video_preview_request_count: 1`, final query `type=Video, category=Search, search=dog`, final item ids `dog-template-000,dog-template-001,dog-template-002`, and `duplicate_item_count: 0`.
- Latest iOS simulator log-scan debug performance/cache summary: `frame_count: 104`, `average_frame_build_time_millis: 14.340`, `90th_percentile_frame_build_time_millis: 36.032`, `99th_percentile_frame_build_time_millis: 59.067`, `worst_frame_build_time_millis: 61.218`, `missed_frame_build_budget_count: 29`, `average_frame_rasterizer_time_millis: 5.084`, `missed_frame_rasterizer_budget_count: 1`, and `max_cache_kb: 940`.
- Latest iOS simulator log-scan `flutter-drive.log` contains `All tests passed` and `Wrote integration response data`, with no `AVPlayer`, `Video player had error`, `PlatformException`, source-error, renderer-error, parser, or generic failure markers matched by the runner scan.
- Latest post-media-cache iOS simulator real-HTTP runner artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-http-after-media-cache-20260615T093800Z` passes with exit code 0, `completion_marker: all_tests_passed_log`, `build_failure_marker: false`, `driver_request_result: true`, `integration_response_data: present`, `video_playback_log_failed: false`, `video_playback_log_marker_count: 0`, `cache_budget_failed: false`, and `cache_budget_violation_count: 0`.
- Latest post-media-cache iOS simulator workflow evidence: `request_count: 10`, `used_cursor_page: true`, `page_query_count: 0`, `cursor_query_count: 4`, `search_requests: cat,dog`, `completed_searches: dog,cat`, `random_request_count: 3`, `random_template_ids: random-any-search-template,random-image-search-template,random-video-search-template`, `media_request_counts: {"/media/template-thumb.png": 1, "/media/template-video-preview.mp4": 1}`, `thumbnail_request_count: 1`, `video_preview_request_count: 1`, final query `type=Video, category=Search, search=dog`, final item ids `dog-template-000,dog-template-001,dog-template-002`, and `duplicate_item_count: 0`.
- Latest post-media-cache iOS simulator debug performance/cache summary: `frame_count: 102`, `average_frame_build_time_millis: 16.109`, `90th_percentile_frame_build_time_millis: 32.284`, `99th_percentile_frame_build_time_millis: 71.087`, `worst_frame_build_time_millis: 72.026`, `missed_frame_build_budget_count: 39`, `average_frame_rasterizer_time_millis: 5.583`, `missed_frame_rasterizer_budget_count: 1`, `cache_before_kb: 0`, `cache_after_kb: 940`, `cache_delta_kb: 940`, and `max_cache_kb: 940`.
- Direct `flutter test --no-pub -d F18FB7FC-73CC-410D-9EB2-821BEC075E20 integration_test/templates_feed_http_backend_smoke_test.dart --dart-define=PETMAGIC_SKIP_FIREBASE=true --reporter=compact` is not counted as evidence: it failed before test execution during Xcode Swift Package Manager resolution with binary-target artifact mapping errors for Firebase/openssl/grpc packages. The QA runner artifact above is counted because it completed through the runner's SPM normalization and build-failure detection path.
- Profile mode cannot run on iOS Simulator: `release/profile builds are only supported for physical devices`.
- The earlier real-HTTP media artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-http-media-debug-20260615T004637Z` is not counted as passing evidence because it exposed the iOS duplicate-media regression: one shared thumbnail URL was requested 29 times. Intermediate partial-fix artifacts also failed with repeated thumbnail requests (`27` then `17`). The final file-reference cache plus no uncached network fallback run above reduced the shared thumbnail request count to `1`.
- Firebase Swift Package products require iOS 15.0. Runner, Podfile, and xcconfig deployment targets are pinned to 15.0 and covered by `test/ios_project_config_test.dart`; Flutter may regenerate the ephemeral Swift package at its default during non-iOS test commands. The QA runner now runs `flutter pub get`, rewrites `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift` from `.iOS("13.0")` to `.iOS("15.0")` for iOS Simulator runs, keeps a short patch watchdog active during `flutter drive`, runs `xcodebuild -resolvePackageDependencies`, adds `--no-pub`, terminates any already-running simulator app before `flutter drive`, and marks a run failed if the log contains build-failure strings even when a stale driver connection reports success.
- Earlier artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-http-backend-debug-20260615T002238Z` is not counted as evidence: the log showed `Failed to build iOS app` and then connected to an already-running gallery test process.
- Earlier artifact `artifacts/mobile-template-feed/ios-simulator-template-feed-http-cache-budget-debug-20260615T022357Z` is not counted as evidence: `xcodebuild -resolvePackageDependencies` succeeded, but `flutter drive` exited before test start with `Xcode failed to resolve Swift Package Manager dependencies`; the retry above passed with a new VM service port.
- First attempt for `artifacts/mobile-template-feed/ios-simulator-template-feed-http-type-transitions-20260615` is not counted as evidence: it failed before test execution with the same one-line Swift Package Manager resolution error. A direct `flutter drive` then passed, and the repeated QA runner with the same `RUN_ID` replaced the artifact with the passing run above.
- Earlier debug retries failed before test execution with VM service/log reader issues:
  - `Error waiting for a debug connection: The log reader failed unexpectedly`
  - `HttpException: Connection closed before full header was received`
  - `HttpException: Connection reset by peer, uri = http://127.0.0.1:61002/.../ws`
  - `RPCError: getVersion: (-32000) Service connection disposed`
- The corresponding `Runner-*.ips` crash reports showed a native startup abort in `FIRInstallations validateAPIKey`. The checked-in placeholder Firebase API key is now syntactically valid so simulator smoke tests can reach Dart UI while still using `PETMAGIC_SKIP_FIREBASE=true`.

Reference crash report path from the failed run:

```text
apps/petmagic-mobile/flutter_17.log
```

## Remaining Required QA

The original goal is not fully closed until these are verified with authoritative evidence:

- Latest environment check on 2026-06-15: `flutter devices` shows Android emulator `emulator-5554`, iOS simulator `F18FB7FC-73CC-410D-9EB2-821BEC075E20`, macOS, and Chrome only; no physical or wireless mobile devices are connected. Fresh local cross-flow QA passed on the Android emulator and iOS simulator after safe-preview mapper hardening. Escalated `nslookup api.petmagic.app` still returns NXDOMAIN, and escalated quoted `curl -I --max-time 10 'https://api.petmagic.app/api/templates/feed?take=1'` still returns `Could not resolve host: api.petmagic.app`.
- Weak physical Android device profile run.
- iOS physical-device profile run.
- Slow-network run against the deployed backend/API, including search and pagination; currently blocked on a resolvable deployed HTTPS API base URL because `api.petmagic.app` returns NXDOMAIN.
- Extended long-session memory/cache growth measurement on physical hardware or a trusted performance lab.
- Network request and byte counting against the deployed backend/CDN and physical devices, including real video-preview downloads. The Android QA runner now captures per-app qtaguid RX/TX byte deltas for new runs, but existing passing artifacts predate that counter and the deployed API host is still unresolved.
- Cache directory size measurement after extended use.
- FPS/frame timing on a physical device or a trusted performance environment.
