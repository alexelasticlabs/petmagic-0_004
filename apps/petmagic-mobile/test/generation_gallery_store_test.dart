import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'markDeletedLocally creates tombstone without existing media record',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = GenerationGalleryStore(
        dio: Dio(),
        preferences: SharedPreferencesAsync(),
        sessionStorage: _InMemoryAuthSessionStorage(_sessionForUser()),
        rootDirectoryResolver: () async => tempDir,
      );

      await store.markDeletedLocally('generation-1', userId: 'user-1');

      expect(await store.loadDeletedGenerationIds(), {'generation-1'});
      expect(await store.loadPendingServerDeleteIds(), ['generation-1']);

      await store.clearPendingServerDelete('generation-1');

      expect(await store.loadDeletedGenerationIds(), {'generation-1'});
      expect(await store.loadPendingServerDeleteIds(), isEmpty);
    },
  );

  test(
    'materializeGenerationMedia does not redownload usable local files',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        requestCount++;
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(const [0xFF, 0xD8, 0xFF, 0xD9]);
        await request.response.close();
      });

      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = _store(tempDir);
      final outputUrl =
          'http://${server.address.address}:${server.port}/result.jpg';
      final generation = _completedGeneration(outputUrl: outputUrl);

      final first = await store.materializeGenerationMedia(generation);

      expect(first, isNotNull);
      expect(first!.isDownloadComplete, isTrue);
      expect(first.previewLocalPath, isNotNull);
      expect(first.outputLocalPath, isNotNull);
      expect(await File(first.previewLocalPath!).length(), greaterThan(0));
      expect(await File(first.outputLocalPath!).length(), greaterThan(0));
      final requestCountAfterFirstMaterialize = requestCount;
      expect(requestCountAfterFirstMaterialize, greaterThanOrEqualTo(2));

      final second = await store.materializeGenerationMedia(generation);

      expect(second, isNotNull);
      expect(second!.isDownloadComplete, isTrue);
      expect(requestCount, requestCountAfterFirstMaterialize);
    },
  );

  test(
    'removeRecord clears final persisted record and media directory',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final preferences = SharedPreferencesAsync();
      final store = _store(tempDir, preferences: preferences);
      final generation = _completedGeneration(
        generationId: 'generation-remove',
      );
      final generationDirectory = _generationDirectory(
        tempDir,
        generation.userId,
        generation.generationId,
      );
      await generationDirectory.create(recursive: true);
      await File(
        '${generationDirectory.path}${Platform.pathSeparator}preview.jpg',
      ).writeAsBytes(_tinyJpegOne);

      await store.upsertReadyItem(generation);
      expect(await store.readLocalRecord(generation.generationId), isNotNull);
      expect(await generationDirectory.exists(), isTrue);

      await store.removeRecord(generation.generationId);

      expect(await store.readLocalRecord(generation.generationId), isNull);
      expect(await store.loadLocalReadyItems(), isEmpty);
      expect(await generationDirectory.exists(), isFalse);

      final reloadedStore = _store(tempDir, preferences: preferences);
      expect(
        await reloadedStore.readLocalRecord(generation.generationId),
        isNull,
      );
      expect(await reloadedStore.loadLocalReadyItems(), isEmpty);
    },
  );

  test(
    'markDeletedLocally treats generation ids as safe path segments',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = _store(tempDir);
      const generationId = '../outside-generation';
      final outsideDirectory = Directory(
        '${tempDir.path}${Platform.pathSeparator}'
        'generation_gallery${Platform.pathSeparator}outside-generation',
      );
      await outsideDirectory.create(recursive: true);
      final sentinelFile = File(
        '${outsideDirectory.path}${Platform.pathSeparator}sentinel.txt',
      );
      await sentinelFile.writeAsString('keep');

      await store.upsertReadyItem(
        _completedGeneration(generationId: generationId),
      );
      await store.markDeletedLocally(generationId, userId: 'user-1');

      expect(await sentinelFile.exists(), isTrue);
      expect(await outsideDirectory.exists(), isTrue);
      expect(await store.loadDeletedGenerationIds(), {generationId});
      expect(await store.loadPendingServerDeleteIds(), [generationId]);
    },
  );

  test(
    'concurrent materializeGenerationMedia is isolated by account scope',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final firstRequestStarted = Completer<void>();
      final responseGate = Completer<void>();
      var requestCount = 0;
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        requestCount++;
        if (!firstRequestStarted.isCompleted) {
          firstRequestStarted.complete();
        }
        await responseGate.future;
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(_tinyJpegOne);
        await request.response.close();
      });

      addTearDown(() async {
        if (!responseGate.isCompleted) {
          responseGate.complete();
        }
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final preferences = SharedPreferencesAsync();
      final store = _store(tempDir, preferences: preferences);
      final outputUrl =
          'http://${server.address.address}:${server.port}/result.jpg';

      final userOneFuture = store.materializeGenerationMedia(
        _completedGeneration(
          generationId: 'shared-generation',
          userId: 'user-1',
          outputUrl: outputUrl,
        ),
      );
      await firstRequestStarted.future;

      final userTwoFuture = store.materializeGenerationMedia(
        _completedGeneration(
          generationId: 'shared-generation',
          userId: 'user-2',
          outputUrl: outputUrl,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      responseGate.complete();

      final records = await Future.wait([userOneFuture, userTwoFuture]);
      final userOneRecord = records[0]!;
      final userTwoRecord = records[1]!;

      expect(userOneRecord.accountScope, 'user-1');
      expect(userTwoRecord.accountScope, 'user-2');
      expect(userOneRecord.outputLocalPath, contains('/user-1/'));
      expect(userTwoRecord.outputLocalPath, contains('/user-2/'));
      expect(
        userOneRecord.outputLocalPath,
        isNot(userTwoRecord.outputLocalPath),
      );
      expect(requestCount, greaterThanOrEqualTo(4));

      final userTwoStore = _store(
        tempDir,
        preferences: preferences,
        session: _sessionForUser('user-2'),
      );
      expect(
        (await userTwoStore.readLocalRecord('shared-generation'))?.accountScope,
        'user-2',
      );
    },
  );

  test(
    'materializeGenerationMedia redownloads corrupted existing local files',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      var serveReplacementMedia = false;
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        requestCount++;
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(
          serveReplacementMedia ? _tinyJpegTwo : _tinyJpegOne,
        );
        await request.response.close();
      });

      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = _store(tempDir);
      final outputUrl =
          'http://${server.address.address}:${server.port}/result.jpg';
      final generation = _completedGeneration(outputUrl: outputUrl);

      final first = await store.materializeGenerationMedia(generation);

      expect(first, isNotNull);
      expect(first!.isDownloadComplete, isTrue);
      final firstPreviewPath = first.previewLocalPath!;
      final firstOutputPath = first.outputLocalPath!;
      expect(await File(firstPreviewPath).readAsBytes(), _tinyJpegOne);
      expect(await File(firstOutputPath).readAsBytes(), _tinyJpegOne);
      final firstRequestCount = requestCount;
      expect(firstRequestCount, greaterThanOrEqualTo(2));

      await File(firstPreviewPath).writeAsString('corrupted preview');
      await File(firstOutputPath).writeAsString('corrupted output');
      serveReplacementMedia = true;

      final second = await store.materializeGenerationMedia(generation);

      expect(second, isNotNull);
      expect(second!.isDownloadComplete, isTrue);
      expect(second.previewLocalPath, firstPreviewPath);
      expect(second.outputLocalPath, firstOutputPath);
      expect(await File(firstPreviewPath).readAsBytes(), _tinyJpegTwo);
      expect(await File(firstOutputPath).readAsBytes(), _tinyJpegTwo);
      expect(requestCount, greaterThan(firstRequestCount));
    },
  );

  test(
    'materializeGenerationMedia refreshes local files when remote URL changes',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestCountsByPath = <String, int>{};
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        requestCountsByPath.update(
          request.uri.path,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(
          request.uri.path == '/second.jpg' ? _tinyJpegTwo : _tinyJpegOne,
        );
        await request.response.close();
      });

      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = _store(tempDir);
      final firstUrl =
          'http://${server.address.address}:${server.port}/first.jpg';
      final secondUrl =
          'http://${server.address.address}:${server.port}/second.jpg';

      final first = await store.materializeGenerationMedia(
        _completedGeneration(outputUrl: firstUrl),
      );
      final firstPreviewPath = first!.previewLocalPath!;
      final firstOutputPath = first.outputLocalPath!;
      expect(await File(firstOutputPath).readAsBytes(), _tinyJpegOne);

      final second = await store.materializeGenerationMedia(
        _completedGeneration(
          outputUrl: secondUrl,
          updatedAtUtc: DateTime.utc(2035, 1, 1, 0, 1),
        ),
      );

      expect(second, isNotNull);
      expect(second!.isDownloadComplete, isTrue);
      expect(second.previewLocalPath, isNot(firstPreviewPath));
      expect(second.outputLocalPath, isNot(firstOutputPath));
      expect(await File(second.outputLocalPath!).readAsBytes(), _tinyJpegTwo);
      expect(await File(firstPreviewPath).exists(), isFalse);
      expect(await File(firstOutputPath).exists(), isFalse);
      expect(requestCountsByPath['/first.jpg'], 2);
      expect(requestCountsByPath['/second.jpg'], 2);
    },
  );

  test('partial record updates preserve existing local media paths', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(const [0xFF, 0xD8, 0xFF, 0xD9]);
      await request.response.close();
    });

    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = _store(tempDir);
    final outputUrl =
        'http://${server.address.address}:${server.port}/result.jpg';
    final generation = _completedGeneration(outputUrl: outputUrl);

    final materialized = await store.materializeGenerationMedia(generation);
    expect(materialized, isNotNull);
    final previewPath = materialized!.previewLocalPath;
    final outputPath = materialized.outputLocalPath;
    expect(previewPath, isNotNull);
    expect(outputPath, isNotNull);

    await store.clearPendingServerDelete(generation.generationId);

    final persisted = await store.readLocalRecord(generation.generationId);
    expect(persisted, isNotNull);
    expect(persisted!.previewLocalPath, previewPath);
    expect(persisted.outputLocalPath, outputPath);
    expect(await File(previewPath!).exists(), isTrue);
    expect(await File(outputPath!).exists(), isTrue);
  });

  test('materializeGenerationMedia rejects empty downloads', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      requestCount++;
      request.response.headers.contentType = ContentType('image', 'jpeg');
      await request.response.close();
    });

    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = _store(tempDir);
    final outputUrl =
        'http://${server.address.address}:${server.port}/empty.jpg';
    final generation = _completedGeneration(outputUrl: outputUrl);

    final record = await store.materializeGenerationMedia(generation);

    expect(record, isNotNull);
    expect(record!.isDownloadComplete, isFalse);
    expect(record.previewLocalPath, isNull);
    expect(record.outputLocalPath, isNull);
    expect(requestCount, greaterThanOrEqualTo(2));

    final persisted = await store.readLocalRecord(generation.generationId);
    expect(persisted, isNotNull);
    expect(persisted!.isDownloadComplete, isFalse);

    final files = await tempDir
        .list(recursive: true)
        .where((entity) => entity is File)
        .toList();
    expect(files, isEmpty);
  });

  test('materializeGenerationMedia rejects non-media downloads', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      requestCount++;
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add('not an image'.codeUnits);
      await request.response.close();
    });

    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = _store(tempDir);
    final outputUrl =
        'http://${server.address.address}:${server.port}/invalid.jpg';
    final generation = _completedGeneration(outputUrl: outputUrl);

    final record = await store.materializeGenerationMedia(generation);

    expect(record, isNotNull);
    expect(record!.isDownloadComplete, isFalse);
    expect(record.previewLocalPath, isNull);
    expect(record.outputLocalPath, isNull);
    expect(requestCount, greaterThanOrEqualTo(2));

    final persisted = await store.readLocalRecord(generation.generationId);
    expect(persisted, isNotNull);
    expect(persisted!.isDownloadComplete, isFalse);

    final files = await tempDir
        .list(recursive: true)
        .where((entity) => entity is File)
        .toList();
    expect(files, isEmpty);
  });

  test('materializeGenerationMedia rejects unsafe remote URLs', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    var requestCount = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final store = _store(tempDir, dio: dio);
    final generation = _completedGeneration(outputUrl: 'javascript:alert(1)');

    final record = await store.materializeGenerationMedia(generation);

    expect(record, isNotNull);
    expect(record!.isDownloadComplete, isFalse);
    expect(record.previewLocalPath, isNull);
    expect(record.outputLocalPath, isNull);
    expect(requestCount, 0);

    final persisted = await store.readLocalRecord(generation.generationId);
    expect(persisted, isNotNull);
    expect(persisted!.isDownloadComplete, isFalse);

    final files = await tempDir
        .list(recursive: true)
        .where((entity) => entity is File)
        .toList();
    expect(files, isEmpty);
  });

  test(
    'local ready cache is pruned while pending server deletes are retained',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = _store(tempDir);

      await store.markDeletedLocally(
        'pending-delete-generation',
        userId: 'user-1',
      );
      for (var index = 0; index < 125; index++) {
        await store.upsertReadyItem(
          _completedGeneration(
            generationId: 'generation-$index',
            updatedAtUtc: DateTime.utc(
              2035,
              1,
              1,
            ).add(Duration(minutes: index)),
          ),
        );
      }

      final readyItems = await store.loadLocalReadyItems();
      final readyIds = readyItems.map((item) => item.generationId).toSet();

      expect(readyItems.length, lessThanOrEqualTo(119));
      expect(readyIds, contains('generation-124'));
      expect(readyIds, isNot(contains('generation-0')));
      expect(await store.loadDeletedGenerationIds(), {
        'pending-delete-generation',
      });
      expect(await store.loadPendingServerDeleteIds(), [
        'pending-delete-generation',
      ]);
    },
  );

  test('local ready cache pruning deletes pruned media directories', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = _store(tempDir);
    final prunedDirectory = _generationDirectory(
      tempDir,
      'user-1',
      'generation-0',
    );
    final retainedDirectory = _generationDirectory(
      tempDir,
      'user-1',
      'generation-124',
    );

    for (var index = 0; index < 125; index++) {
      if (index == 0) {
        await prunedDirectory.create(recursive: true);
        await File(
          '${prunedDirectory.path}${Platform.pathSeparator}preview.jpg',
        ).writeAsBytes(_tinyJpegOne);
      }
      if (index == 124) {
        await retainedDirectory.create(recursive: true);
        await File(
          '${retainedDirectory.path}${Platform.pathSeparator}preview.jpg',
        ).writeAsBytes(_tinyJpegTwo);
      }

      await store.upsertReadyItem(
        _completedGeneration(
          generationId: 'generation-$index',
          updatedAtUtc: DateTime.utc(2035, 1, 1).add(Duration(minutes: index)),
        ),
      );
    }

    final readyIds = (await store.loadLocalReadyItems())
        .map((item) => item.generationId)
        .toSet();

    expect(readyIds, isNot(contains('generation-0')));
    expect(readyIds, contains('generation-124'));
    expect(await prunedDirectory.exists(), isFalse);
    expect(await retainedDirectory.exists(), isTrue);
  });

  test(
    'cleanupCurrentAccountArtifacts removes orphan directories and part files',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = _store(tempDir);
      final knownDirectory = _generationDirectory(
        tempDir,
        'user-1',
        'generation-known',
      );
      final orphanDirectory = _generationDirectory(
        tempDir,
        'user-1',
        'generation-orphan',
      );
      final otherAccountDirectory = _generationDirectory(
        tempDir,
        'user-2',
        'generation-other-account',
      );

      await store.upsertReadyItem(
        _completedGeneration(generationId: 'generation-known'),
      );
      await knownDirectory.create(recursive: true);
      await File(
        '${knownDirectory.path}${Platform.pathSeparator}preview.jpg',
      ).writeAsBytes(_tinyJpegOne);
      final stalePartFile = File(
        '${knownDirectory.path}${Platform.pathSeparator}preview.jpg.part',
      );
      await stalePartFile.writeAsBytes(const [1, 2, 3]);
      await orphanDirectory.create(recursive: true);
      await File(
        '${orphanDirectory.path}${Platform.pathSeparator}orphan.jpg',
      ).writeAsBytes(_tinyJpegTwo);
      await otherAccountDirectory.create(recursive: true);

      await store.cleanupCurrentAccountArtifacts();

      expect(await knownDirectory.exists(), isTrue);
      expect(
        await File(
          '${knownDirectory.path}${Platform.pathSeparator}preview.jpg',
        ).exists(),
        isTrue,
      );
      expect(await stalePartFile.exists(), isFalse);
      expect(await orphanDirectory.exists(), isFalse);
      expect(await otherAccountDirectory.exists(), isTrue);
    },
  );

  test(
    'purgeAllScopes removes persisted media records and directories for every account',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final preferences = SharedPreferencesAsync();
      final userOneStore = _store(
        tempDir,
        preferences: preferences,
        session: _sessionForUser('user-1'),
      );
      final userTwoStore = _store(
        tempDir,
        preferences: preferences,
        session: _sessionForUser('user-2'),
      );
      final userOneDirectory = Directory(
        '${tempDir.path}${Platform.pathSeparator}'
        'generation_gallery${Platform.pathSeparator}'
        'user-1${Platform.pathSeparator}generation-user-1',
      );
      final userTwoDirectory = Directory(
        '${tempDir.path}${Platform.pathSeparator}'
        'generation_gallery${Platform.pathSeparator}'
        'user-2${Platform.pathSeparator}generation-user-2',
      );

      await userOneStore.upsertReadyItem(
        _completedGeneration(
          generationId: 'generation-user-1',
          userId: 'user-1',
        ),
      );
      await userTwoStore.upsertReadyItem(
        _completedGeneration(
          generationId: 'generation-user-2',
          userId: 'user-2',
        ),
      );
      await userOneDirectory.create(recursive: true);
      await userTwoDirectory.create(recursive: true);

      expect(await userOneStore.loadLocalReadyItems(), hasLength(1));
      expect(await userTwoStore.loadLocalReadyItems(), hasLength(1));
      expect(await userOneDirectory.exists(), isTrue);
      expect(await userTwoDirectory.exists(), isTrue);

      await userOneStore.purgeAllScopes();

      expect(await userOneStore.loadLocalReadyItems(), isEmpty);
      expect(await userTwoStore.loadLocalReadyItems(), isEmpty);
      expect(await userOneDirectory.exists(), isFalse);
      expect(await userTwoDirectory.exists(), isFalse);
    },
  );
}

const _tinyJpegOne = [
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
  0x4A,
  0x46,
  0x49,
  0x46,
  0x00,
  0x01,
  0xFF,
  0xD9,
];

const _tinyJpegTwo = [
  0xFF,
  0xD8,
  0xFF,
  0xE1,
  0x00,
  0x10,
  0x45,
  0x78,
  0x69,
  0x66,
  0x00,
  0x00,
  0xFF,
  0xD9,
];

GenerationGalleryStore _store(
  Directory rootDirectory, {
  Dio? dio,
  SharedPreferencesAsync? preferences,
  AuthSession? session,
}) {
  return GenerationGalleryStore(
    dio: dio ?? Dio(),
    preferences: preferences ?? SharedPreferencesAsync(),
    sessionStorage: _InMemoryAuthSessionStorage(session ?? _sessionForUser()),
    rootDirectoryResolver: () async => rootDirectory,
  );
}

Directory _generationDirectory(
  Directory rootDirectory,
  String accountScope,
  String generationId,
) {
  return Directory(
    '${rootDirectory.path}${Platform.pathSeparator}'
    'generation_gallery${Platform.pathSeparator}'
    '$accountScope${Platform.pathSeparator}$generationId',
  );
}

TemplateGenerationResult _completedGeneration({
  String generationId = 'generation-1',
  String userId = 'user-1',
  DateTime? updatedAtUtc,
  String? outputUrl,
}) {
  final timestamp = updatedAtUtc ?? DateTime.utc(2035);
  return TemplateGenerationResult(
    generationId: generationId,
    userId: userId,
    templateId: 'template-1',
    status: TemplateGenerationStatus.completed,
    tokenCost: 1,
    attemptCount: 1,
    createdAtUtc: timestamp,
    updatedAtUtc: timestamp,
    userMediaExpired: false,
    templateTitle: 'Magic portrait',
    templateType: 'image',
    outputUrl: outputUrl ?? 'https://cdn.petmagic.example/$generationId.jpg',
  );
}

AuthSession _sessionForUser([String userId = 'user-1']) {
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: DateTime.utc(2035),
    user: MobileUserProfile(
      userId: userId,
      email: 'pet@example.com',
      displayName: 'Pet Parent',
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: false,
      legalAcceptance: MobileLegalAcceptanceStatus(
        termsOfUseAccepted: true,
        termsOfUseAcceptedVersion: '1',
        termsOfUseAcceptedAtUtc: null,
        privacyPolicyAccepted: true,
        privacyPolicyAcceptedVersion: '1',
        privacyPolicyAcceptedAtUtc: null,
        currentTermsOfUseVersion: '1',
        currentPrivacyPolicyVersion: '1',
        requiresAcceptance: false,
      ),
      roles: ['User'],
      avatar: null,
    ),
  );
}

class _InMemoryAuthSessionStorage extends AuthSessionStorage {
  _InMemoryAuthSessionStorage(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;
}
