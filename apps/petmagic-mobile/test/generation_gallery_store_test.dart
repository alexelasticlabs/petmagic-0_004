import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(userOneRecord.outputLocalPath, contains('user-1'));
      expect(userTwoRecord.outputLocalPath, contains('user-2'));
      expect(userOneRecord.previewLocalPath, userOneRecord.outputLocalPath);
      expect(userTwoRecord.previewLocalPath, userTwoRecord.outputLocalPath);
      expect(
        userOneRecord.outputLocalPath,
        isNot(userTwoRecord.outputLocalPath),
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
}
