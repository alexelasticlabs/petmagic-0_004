import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generation_gallery_store_test_support.dart';

const _tinyJpegOne = tinyJpegOne;
const _tinyJpegTwo = tinyJpegTwo;
const _tinyMp4 = tinyMp4;

final _store = buildGenerationGalleryStore;
final _completedGeneration = completedGenerationForTest;
final _sessionForUser = sessionForUser;

void main() {
  configureGenerationGalleryStoreTestHarness();

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
      expect(first.previewLocalPath, first.outputLocalPath);
      expect(await File(first.previewLocalPath!).length(), greaterThan(0));
      expect(await File(first.outputLocalPath!).length(), greaterThan(0));
      final requestCountAfterFirstMaterialize = requestCount;
      expect(requestCountAfterFirstMaterialize, 1);

      final second = await store.materializeGenerationMedia(generation);

      expect(second, isNotNull);
      expect(second!.isDownloadComplete, isTrue);
      expect(requestCount, requestCountAfterFirstMaterialize);
    },
  );

  test(
    'materializeGenerationMedia skips completed media without account scope',
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
        request.response.add(_tinyJpegOne);
        await request.response.close();
      });

      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = _store(tempDir, session: null, useDefaultSession: false);
      final outputUrl =
          'http://${server.address.address}:${server.port}/result.jpg';

      final record = await store.materializeGenerationMedia(
        _completedGeneration(userId: '', outputUrl: outputUrl),
      );

      expect(record, isNull);
      expect(requestCount, 0);
      expect(await store.loadLocalReadyItems(), isEmpty);
      expect(await tempDir.list(recursive: true).toList(), isEmpty);
    },
  );

  test(
    'materializeGenerationMedia uses result preview thumbnail separately from output',
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
          request.uri.path == '/thumb.jpg' ? _tinyJpegOne : _tinyJpegTwo,
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
      final baseUrl = 'http://${server.address.address}:${server.port}';
      final generation = _completedGeneration(
        outputUrl: '$baseUrl/result.jpg',
        resultPreviewUrl: '$baseUrl/thumb.jpg',
      );

      final record = await store.materializeGenerationMedia(generation);

      expect(record, isNotNull);
      expect(record!.isDownloadComplete, isTrue);
      expect(record.previewLocalPath, isNotNull);
      expect(record.outputLocalPath, isNotNull);
      expect(record.previewLocalPath, isNot(record.outputLocalPath));
      expect(await File(record.previewLocalPath!).readAsBytes(), _tinyJpegOne);
      expect(await File(record.outputLocalPath!).readAsBytes(), _tinyJpegTwo);
      expect(requestCountsByPath, {'/thumb.jpg': 1, '/result.jpg': 1});
    },
  );

  test(
    'materializeGenerationMedia keeps signed URL secrets out of persisted records',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestedQueries = <String>[];
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        requestedQueries.add(request.uri.query);
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(_tinyJpegOne);
        await request.response.close();
      });

      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final preferences = SharedPreferencesAsync();
      final store = _store(tempDir, preferences: preferences);
      final baseUrl = 'http://${server.address.address}:${server.port}';
      final signedOutputUrl =
          '$baseUrl/result.jpg?X-Amz-Signature=secret&token=raw#fragment';

      final record = await store.materializeGenerationMedia(
        _completedGeneration(outputUrl: signedOutputUrl),
      );
      final keys = await preferences.getKeys();
      final cacheKey = keys.singleWhere(
        (key) => key.startsWith('generation_gallery_entries_v2:'),
      );
      final raw = await preferences.getString(cacheKey);
      final persisted = await store.readLocalRecord(record!.generationId);

      expect(requestedQueries.single, contains('X-Amz-Signature=secret'));
      expect(record.isDownloadComplete, isTrue);
      expect(cacheKey, isNot(contains('user-1')));
      expect(raw, isNotNull);
      expect(raw, isNot(contains('X-Amz-Signature')));
      expect(raw, isNot(contains('token=raw')));
      expect(raw, isNot(contains('fragment')));
      expect(persisted?.outputRemoteUrl, '$baseUrl/result.jpg');
      expect(persisted?.previewRemoteUrl, '$baseUrl/result.jpg');
    },
  );

  test(
    'materializeGenerationMedia ignores unsafe result preview when output is safe',
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
        request.response.add(_tinyJpegOne);
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
      final generation = _completedGeneration(
        outputUrl: outputUrl,
        resultPreviewUrl: 'javascript:alert(1)',
      );

      final record = await store.materializeGenerationMedia(generation);

      expect(record, isNotNull);
      expect(record!.previewRemoteUrl, outputUrl);
      expect(record.outputRemoteUrl, outputUrl);
      expect(record.isDownloadComplete, isTrue);
      expect(record.previewLocalPath, record.outputLocalPath);
      expect(await File(record.outputLocalPath!).readAsBytes(), _tinyJpegOne);
      expect(requestCount, 1);
    },
  );

  test(
    'materializeGenerationMedia stores opaque video outputs as mp4 without preview',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        requestCount++;
        request.response.headers.contentType = ContentType('video', 'mp4');
        request.response.add(_tinyMp4);
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
          'http://${server.address.address}:${server.port}/result';
      final generation = _completedGeneration(
        templateType: 'Video',
        outputUrl: outputUrl,
      );

      final record = await store.materializeGenerationMedia(generation);

      expect(record, isNotNull);
      expect(record!.isDownloadComplete, isTrue);
      expect(record.previewLocalPath, isNull);
      expect(record.outputLocalPath, isNotNull);
      expect(record.outputLocalPath, endsWith('.mp4'));
      expect(await File(record.outputLocalPath!).readAsBytes(), _tinyMp4);
      expect(requestCount, 1);
    },
  );

  test(
    'materializeGenerationMedia bounds long safe generation id path segments',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(_tinyJpegOne);
        await request.response.close();
      });

      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      const longGenerationId =
          'generation-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final store = _store(tempDir);
      final outputUrl =
          'http://${server.address.address}:${server.port}/result.jpg';

      final record = await store.materializeGenerationMedia(
        _completedGeneration(
          generationId: longGenerationId,
          outputUrl: outputUrl,
        ),
      );

      expect(record, isNotNull);
      expect(record!.generationId, longGenerationId);
      expect(record.outputLocalPath, isNotNull);
      final generationSegment = File(
        record.outputLocalPath!,
      ).parent.path.split(Platform.pathSeparator).last;
      expect(generationSegment, isNot(longGenerationId));
      expect(generationSegment.length, lessThanOrEqualTo(89));
      expect(
        generationSegment,
        matches(RegExp(r'^[a-zA-Z0-9._-]+_[0-9a-f]{8}$')),
      );
      expect(await File(record.outputLocalPath!).exists(), isTrue);
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
      expect(userOneRecord.outputLocalPath, isNot(contains('user-1')));
      expect(userTwoRecord.outputLocalPath, isNot(contains('user-2')));
      expect(userOneRecord.previewLocalPath, userOneRecord.outputLocalPath);
      expect(userTwoRecord.previewLocalPath, userTwoRecord.outputLocalPath);
      expect(
        userOneRecord.outputLocalPath,
        isNot(userTwoRecord.outputLocalPath),
      );
      final preferenceKeys = await preferences.getKeys();
      expect(preferenceKeys.any((key) => key.contains('user-1')), isFalse);
      expect(preferenceKeys.any((key) => key.contains('user-2')), isFalse);
      for (final key in preferenceKeys) {
        final raw = await preferences.getString(key);
        expect(raw, isNot(contains('user-1')));
        expect(raw, isNot(contains('user-2')));
      }
      expect(
        preferenceKeys.where(
          (key) => key.startsWith('generation_gallery_entries_v2:'),
        ),
        hasLength(2),
      );
      expect(requestCount, greaterThanOrEqualTo(2));

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
    'materializeGenerationMedia does not resurrect locally deleted records',
    () async {
      final source = await File(
        'lib/features/templates/data/generation_gallery_store_storage.part.dart',
      ).readAsString();
      final body = _extractFunctionBody(
        source,
        'Future<GenerationGalleryMediaRecord?>\n_galleryMaterializeGenerationMediaInternal(',
      );

      expect(body, contains('latestEntry?.isDeletedLocally == true'));
      expect(body, contains('await _galleryDeleteLocalPath('));
      expect(body, contains('baseEntry.accountScope'));
      expect(body, contains('generation.generationId'));
      expect(body, contains('previewLocalPath'));
      expect(body, contains('outputLocalPath'));
      expect(body, contains('return latestEntry;'));
    },
  );

  test(
    'loadLocalReadyItems migrates legacy raw user scope preference key',
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
      const legacyScope = 'legacy-user-1';
      final record = GenerationGalleryMediaRecord(
        generationId: 'legacy-generation',
        accountScope: legacyScope,
        userId: legacyScope,
        status: 'completed',
        templateTitle: 'Legacy',
        templateType: 'image',
        updatedAtUtc: DateTime.utc(2035),
        lastSyncedAtUtc: DateTime.utc(2035),
        version: 1,
        isDownloadComplete: true,
      );
      await preferences.setString(
        'generation_gallery_entries_v1:$legacyScope',
        jsonEncode([record.toJson()]),
      );

      final store = _store(
        tempDir,
        preferences: preferences,
        session: _sessionForUser(legacyScope),
      );

      final items = await store.loadLocalReadyItems();

      expect(
        items.map((item) => item.generationId),
        contains('legacy-generation'),
      );
      expect(
        await preferences.getString(
          'generation_gallery_entries_v1:$legacyScope',
        ),
        isNull,
      );
      final keys = await preferences.getKeys();
      expect(keys.any((key) => key.contains(legacyScope)), isFalse);
      expect(
        keys.where((key) => key.startsWith('generation_gallery_entries_v2:')),
        hasLength(1),
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
      expect(firstPreviewPath, firstOutputPath);
      expect(await File(firstPreviewPath).readAsBytes(), _tinyJpegOne);
      expect(await File(firstOutputPath).readAsBytes(), _tinyJpegOne);
      final firstRequestCount = requestCount;
      expect(firstRequestCount, 1);

      await File(firstPreviewPath).writeAsString('corrupted preview');
      await File(firstOutputPath).writeAsString('corrupted output');
      serveReplacementMedia = true;

      final second = await store.materializeGenerationMedia(generation);

      expect(second, isNotNull);
      expect(second!.isDownloadComplete, isTrue);
      expect(second.previewLocalPath, firstPreviewPath);
      expect(second.outputLocalPath, firstOutputPath);
      expect(second.previewLocalPath, second.outputLocalPath);
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
      expect(second.previewLocalPath, second.outputLocalPath);
      expect(await File(second.outputLocalPath!).readAsBytes(), _tinyJpegTwo);
      expect(await File(firstPreviewPath).exists(), isFalse);
      expect(await File(firstOutputPath).exists(), isFalse);
      expect(requestCountsByPath['/first.jpg'], 1);
      expect(requestCountsByPath['/second.jpg'], 1);
    },
  );

  test(
    'materializeGenerationMedia clears local paths when changed URL fails',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        if (request.uri.path == '/first.jpg') {
          request.response.add(_tinyJpegOne);
        }
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
      expect(second!.previewRemoteUrl, secondUrl);
      expect(second.outputRemoteUrl, secondUrl);
      expect(second.previewLocalPath, isNull);
      expect(second.outputLocalPath, isNull);
      expect(second.isDownloadComplete, isFalse);
      expect(await File(firstPreviewPath).exists(), isFalse);
      expect(await File(firstOutputPath).exists(), isFalse);
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
    expect(requestCount, 1);

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
    expect(requestCount, 1);

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

  test('background materialization respects per-session item cap', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      requestCount++;
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(_tinyJpegOne);
      await request.response.close();
    });

    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = _store(tempDir, maxBackgroundMaterializationsPerSession: 1);
    final baseUrl = 'http://${server.address.address}:${server.port}';

    final first = await store.materializeGenerationMedia(
      _completedGeneration(
        generationId: 'generation-1',
        outputUrl: '$baseUrl/one.jpg',
      ),
      background: true,
    );
    final second = await store.materializeGenerationMedia(
      _completedGeneration(
        generationId: 'generation-2',
        outputUrl: '$baseUrl/two.jpg',
      ),
      background: true,
    );

    expect(first, isNotNull);
    expect(first!.isDownloadComplete, isTrue);
    expect(second, isNotNull);
    expect(second!.isDownloadComplete, isFalse);
    expect(
      second.materializationFailureCode,
      'background_session_cap_exceeded',
    );
    expect(second.outputLocalPath, isNull);
    expect(requestCount, 1);
  });

  test('background materialization respects file byte budget', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      requestCount++;
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(_tinyJpegOne);
      await request.response.close();
    });

    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = _store(tempDir, maxBackgroundFileBytes: 4);
    final outputUrl =
        'http://${server.address.address}:${server.port}/oversize.jpg';

    final record = await store.materializeGenerationMedia(
      _completedGeneration(outputUrl: outputUrl),
      background: true,
    );

    expect(record, isNotNull);
    expect(record!.isDownloadComplete, isFalse);
    expect(record.previewLocalPath, isNull);
    expect(record.outputLocalPath, isNull);
    expect(record.materializationFailureCode, 'background_file_too_large');
    expect(record.localBytes, 0);
    expect(requestCount, 1);
    final files = await tempDir
        .list(recursive: true)
        .where((entity) => entity is File)
        .toList();
    expect(files, isEmpty);
  });

  test(
    'background materialization cancels oversized downloads early',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      var bytesWritten = 0;
      const chunkBytes = 4096;
      const totalBytes = 256 * 1024;
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        requestCount++;
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.contentLength = totalBytes;

        final chunk = Uint8List(chunkBytes);
        for (var offset = 0; offset < totalBytes; offset += chunkBytes) {
          try {
            request.response.add(chunk);
            await request.response.flush();
            bytesWritten += chunkBytes;
            await Future<void>.delayed(const Duration(milliseconds: 1));
          } on Object {
            break;
          }
        }

        try {
          await request.response.close();
        } on Object {
          // Client-side byte budget cancellation closes the socket first.
        }
      });

      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = _store(tempDir, maxBackgroundFileBytes: 8 * 1024);
      final outputUrl =
          'http://${server.address.address}:${server.port}/large.jpg';

      final record = await store.materializeGenerationMedia(
        _completedGeneration(outputUrl: outputUrl),
        background: true,
      );

      expect(record, isNotNull);
      expect(record!.isDownloadComplete, isFalse);
      expect(record.materializationFailureCode, 'background_file_too_large');
      expect(record.outputLocalPath, isNull);
      expect(requestCount, 1);
      expect(bytesWritten, lessThan(totalBytes));
    },
  );

  test('background materialization backs off failed files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      requestCount++;
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final nowUtc = DateTime.utc(2035, 1, 1, 12);
    final store = _store(tempDir, clock: () => nowUtc);
    final generation = _completedGeneration(
      outputUrl: 'http://${server.address.address}:${server.port}/missing.jpg',
    );

    final first = await store.materializeGenerationMedia(
      generation,
      background: true,
    );
    final second = await store.materializeGenerationMedia(
      generation,
      background: true,
    );

    expect(first, isNotNull);
    expect(first!.isDownloadComplete, isFalse);
    expect(first.materializationFailureCode, 'storage_unavailable');
    expect(first.materializationFailureCount, 1);
    expect(
      first.materializationBackoffUntilUtc,
      nowUtc.add(Duration(minutes: 15)),
    );
    expect(second, isNotNull);
    expect(
      second!.materializationBackoffUntilUtc,
      first.materializationBackoffUntilUtc,
    );
    expect(requestCount, 1);
  });

  test(
    'background materialization caches video preview without full output',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-gallery-store-test-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requestPaths = <String>[];
      late final StreamSubscription<HttpRequest> subscription;
      subscription = server.listen((request) async {
        requestPaths.add(request.uri.path);
        if (request.uri.path.endsWith('.mp4')) {
          request.response.headers.contentType = ContentType('video', 'mp4');
          request.response.add(_tinyMp4);
        } else {
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.add(_tinyJpegOne);
        }
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
      final baseUrl = 'http://${server.address.address}:${server.port}';

      final record = await store.materializeGenerationMedia(
        _completedGeneration(
          templateType: 'video',
          resultPreviewUrl: '$baseUrl/preview.jpg',
          outputUrl: '$baseUrl/result.mp4',
        ),
        background: true,
      );

      expect(record, isNotNull);
      expect(record!.isDownloadComplete, isFalse);
      expect(record.previewLocalPath, isNotNull);
      expect(record.outputLocalPath, isNull);
      expect(
        record.materializationFailureCode,
        'background_video_output_skipped',
      );
      expect(requestPaths, ['/preview.jpg']);
    },
  );

  test('gallery cache prune removes old local media by byte quota', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(_tinyJpegOne);
      await request.response.close();
    });

    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = _store(tempDir, maxGalleryCacheBytesPerScope: 20);
    final baseUrl = 'http://${server.address.address}:${server.port}';
    final older = await store.materializeGenerationMedia(
      _completedGeneration(
        generationId: 'older-generation',
        updatedAtUtc: DateTime.utc(2035, 1, 1, 10),
        outputUrl: '$baseUrl/older.jpg',
      ),
    );
    final olderOutputPath = older!.outputLocalPath;

    final newer = await store.materializeGenerationMedia(
      _completedGeneration(
        generationId: 'newer-generation',
        updatedAtUtc: DateTime.utc(2035, 1, 1, 11),
        outputUrl: '$baseUrl/newer.jpg',
      ),
    );

    final prunedOlder = await store.readLocalRecord('older-generation');
    final retainedNewer = await store.readLocalRecord('newer-generation');

    expect(newer, isNotNull);
    expect(prunedOlder, isNotNull);
    expect(prunedOlder!.isDownloadComplete, isFalse);
    expect(prunedOlder.outputLocalPath, isNull);
    expect(prunedOlder.materializationFailureCode, 'cache_byte_pruned');
    expect(retainedNewer, isNotNull);
    expect(retainedNewer!.isDownloadComplete, isTrue);
    expect(retainedNewer.outputLocalPath, isNotNull);
    expect(await File(olderOutputPath!).exists(), isFalse);
  });
}

String _extractFunctionBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    fail('Function signature was not found: $signature');
  }

  var parenDepth = 0;
  var openBrace = -1;
  for (var index = start; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')') {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      openBrace = index;
      break;
    }
  }
  if (openBrace < 0) {
    fail('Function body was not found: $signature');
  }

  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }
    depth--;
    if (depth == 0) {
      return source.substring(openBrace, index + 1);
    }
  }

  fail('Function body was not closed: $signature');
}
