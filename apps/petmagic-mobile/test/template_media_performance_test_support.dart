import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';

late Directory sharedMediaCacheRoot;
late PathProviderPlatform originalPathProvider;

void configureTemplateMediaPerformanceHarness({bool ensureWidgets = true}) {
  if (ensureWidgets) {
    TestWidgetsFlutterBinding.ensureInitialized();
  }
  setUpAll(() async {
    originalPathProvider = PathProviderPlatform.instance;
    sharedMediaCacheRoot = await Directory.systemTemp.createTemp(
      'petmagic-template-media-cache-shared-test-',
    );
    PathProviderPlatform.instance = FakeTemplateMediaPathProviderPlatform(
      sharedMediaCacheRoot,
    );
  });

  tearDownAll(() async {
    await TemplateMediaCache.clearAll();
    PathProviderPlatform.instance = originalPathProvider;
    if (await sharedMediaCacheRoot.exists()) {
      await sharedMediaCacheRoot.delete(recursive: true);
    }
  });
}

class FakeTemplateMediaPathProviderPlatform extends PathProviderPlatform {
  FakeTemplateMediaPathProviderPlatform(this.root);

  final Directory root;

  @override
  Future<String?> getTemporaryPath() async {
    return _ensureDirectory('tmp').path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return _ensureDirectory('support').path;
  }

  @override
  Future<String?> getApplicationCachePath() async {
    return _ensureDirectory('cache').path;
  }

  Directory _ensureDirectory(String name) {
    final directory = Directory('${root.path}/$name');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}

Future<File> writeCacheFile(
  Directory root,
  String fileName, {
  required int bytes,
  required DateTime modifiedAt,
}) async {
  final file = File('${root.path}/$fileName');
  await file.writeAsBytes(List<int>.filled(bytes, 1), flush: true);
  await file.setLastModified(modifiedAt);
  return file;
}

String readGenerationStatusSectionsLibrarySource() {
  const files = [
    'lib/features/templates/presentation/generation_status_page_sections.dart',
    'lib/features/templates/presentation/generation_status_page_active_card.part.dart',
    'lib/features/templates/presentation/generation_status_page_active_chrome.part.dart',
    'lib/features/templates/presentation/generation_status_page_result_cards.part.dart',
    'lib/features/templates/presentation/generation_status_page_result_action_widgets.part.dart',
    'lib/features/templates/presentation/generation_status_page_result_details.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}

String readTemplatesPageLibrarySource() {
  const files = [
    'lib/features/templates/presentation/templates_page.dart',
    'lib/features/templates/presentation/templates_page_feed.part.dart',
    'lib/features/templates/presentation/templates_page_feed_slivers.part.dart',
    'lib/features/templates/presentation/templates_page_generation_flow.part.dart',
    'lib/features/templates/presentation/templates_page_pet_photo_picker.part.dart',
    'lib/features/templates/presentation/templates_page_lifecycle.part.dart',
    'lib/features/templates/presentation/templates_page_template_actions.part.dart',
    'lib/features/templates/presentation/templates_page_view.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}
