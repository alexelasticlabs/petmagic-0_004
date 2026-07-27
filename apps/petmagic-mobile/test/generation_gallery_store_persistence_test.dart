import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generation_gallery_store_test_support.dart';

const _tinyJpegOne = tinyJpegOne;
const _tinyJpegTwo = tinyJpegTwo;

final _store = buildGenerationGalleryStore;
final _completedGeneration = completedGenerationForTest;
final _generationDirectory = generationDirectoryForTest;
final _sessionForUser = sessionForUser;

String _entriesKeyForScope(String accountScope) {
  final scopeSegment = sha256
      .convert(utf8.encode(accountScope.trim().toLowerCase()))
      .toString();
  return 'generation_gallery_entries_v2:$scopeSegment';
}

void main() {
  configureGenerationGalleryStoreTestHarness();

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

      final store = _store(tempDir);

      await store.markDeletedLocally('generation-1', userId: 'user-1');

      expect(await store.loadDeletedGenerationIds(), {'generation-1'});
      expect(await store.loadPendingServerDeleteIds(), ['generation-1']);

      await store.clearPendingServerDelete('generation-1');

      expect(await store.loadDeletedGenerationIds(), {'generation-1'});
      expect(await store.loadPendingServerDeleteIds(), isEmpty);
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
    'clearCurrentAccountDownloads removes files while preserving deletion state',
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
      final generation = _completedGeneration(generationId: 'generation-clear');
      final generationDirectory = _generationDirectory(
        tempDir,
        generation.userId,
        generation.generationId,
      );
      await generationDirectory.create(recursive: true);
      final localFile = File(
        '${generationDirectory.path}${Platform.pathSeparator}result.jpg',
      );
      await localFile.writeAsBytes(_tinyJpegOne);
      final record = await store.upsertReadyItem(generation);
      await preferences.setString(
        _entriesKeyForScope(generation.userId),
        jsonEncode([
          record
              .copyWith(
                outputLocalPath: localFile.path,
                isDownloadComplete: true,
                isDeletedLocally: true,
                pendingServerDelete: true,
                localBytes: _tinyJpegOne.length,
              )
              .toJson(),
        ]),
      );

      await store.clearCurrentAccountDownloads();

      expect(await generationDirectory.exists(), isFalse);
      final cleared = await store.readLocalRecord(generation.generationId);
      expect(cleared, isNotNull);
      expect(cleared!.outputLocalPath, isNull);
      expect(cleared.previewLocalPath, isNull);
      expect(cleared.localBytes, 0);
      expect(cleared.isDownloadComplete, isFalse);
      expect(cleared.isDeletedLocally, isTrue);
      expect(cleared.pendingServerDelete, isTrue);
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

  test('loadLocalReadyItems sanitizes legacy v2 persisted metadata', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-gallery-store-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final preferences = SharedPreferencesAsync();
    const accountScope = 'legacy-user-1';
    final cacheKey = _entriesKeyForScope(accountScope);
    await preferences.setString(
      cacheKey,
      jsonEncode([
        {
          'generationId': 'legacy-generation',
          'accountScope': accountScope,
          'userId': accountScope,
          'status': 'completed',
          'templateTitle': 'Legacy',
          'templateType': 'image',
          'updatedAtUtc': DateTime.utc(2035).toIso8601String(),
          'previewRemoteUrl':
              'https://cdn.petmagic.example/preview.jpg?signature=secret',
          'outputRemoteUrl':
              'https://cdn.petmagic.example/output.jpg?token=secret#fragment',
          'previewLocalPath': null,
          'outputLocalPath': null,
          'isDeletedLocally': false,
          'isDownloadComplete': true,
          'lastSyncedAtUtc': DateTime.utc(2035).toIso8601String(),
          'version': 1,
          'pendingServerDelete': false,
          'materializationFailureCount': 0,
          'localBytes': 0,
        },
      ]),
    );
    final store = _store(
      tempDir,
      preferences: preferences,
      session: _sessionForUser(accountScope),
    );

    final items = await store.loadLocalReadyItems();
    final rewritten = await preferences.getString(cacheKey);

    expect(items, hasLength(1));
    expect(items.single.userId, accountScope);
    expect(items.single.accountScope, accountScope);
    expect(
      items.single.previewRemoteUrl,
      'https://cdn.petmagic.example/preview.jpg',
    );
    expect(
      items.single.outputRemoteUrl,
      'https://cdn.petmagic.example/output.jpg',
    );
    expect(rewritten, isNotNull);
    expect(rewritten, isNot(contains('"accountScope"')));
    expect(rewritten, isNot(contains('"userId"')));
    expect(rewritten, isNot(contains('signature=secret')));
    expect(rewritten, isNot(contains('token=secret')));
    expect(rewritten, isNot(contains('fragment')));
  });

  test(
    'loadLocalReadyItems rejects persisted local paths outside cache root',
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
      const accountScope = 'user-1';
      const generationId = 'generation-external-path';
      final cacheKey = _entriesKeyForScope(accountScope);
      final externalFile = File(
        '${tempDir.path}${Platform.pathSeparator}outside-gallery.jpg',
      );
      await externalFile.writeAsBytes(_tinyJpegOne);
      await preferences.setString(
        cacheKey,
        jsonEncode([
          {
            'generationId': generationId,
            'status': 'completed',
            'templateTitle': 'Unsafe local path',
            'templateType': 'image',
            'updatedAtUtc': DateTime.utc(2035).toIso8601String(),
            'previewRemoteUrl': 'https://cdn.petmagic.example/preview.jpg',
            'outputRemoteUrl': 'https://cdn.petmagic.example/output.jpg',
            'previewLocalPath': externalFile.path,
            'outputLocalPath': externalFile.path,
            'isDeletedLocally': false,
            'isDownloadComplete': true,
            'lastSyncedAtUtc': DateTime.utc(2035).toIso8601String(),
            'version': 1,
            'pendingServerDelete': false,
            'materializationFailureCount': 0,
            'localBytes': _tinyJpegOne.length,
          },
        ]),
      );
      final store = _store(
        tempDir,
        preferences: preferences,
        session: _sessionForUser(accountScope),
      );

      final items = await store.loadLocalReadyItems();
      final rewritten = await preferences.getString(cacheKey);

      expect(items, hasLength(1));
      expect(items.single.previewLocalPath, isNull);
      expect(items.single.outputLocalPath, isNull);
      expect(items.single.isDownloadComplete, isFalse);
      expect(items.single.localBytes, 0);
      expect(await externalFile.exists(), isTrue);
      expect(rewritten, isNotNull);
      expect(rewritten, isNot(contains('outside-gallery.jpg')));
    },
  );

  test(
    'loadLocalReadyItems rewrites trusted absolute local paths as relative cache paths',
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
      const accountScope = 'user-1';
      const generationId = 'generation-local-path';
      final cacheKey = _entriesKeyForScope(accountScope);
      final generationDirectory = _generationDirectory(
        tempDir,
        accountScope,
        generationId,
      );
      await generationDirectory.create(recursive: true);
      final mediaFile = File(
        '${generationDirectory.path}${Platform.pathSeparator}result_123.jpg',
      );
      await mediaFile.writeAsBytes(_tinyJpegOne);
      await preferences.setString(
        cacheKey,
        jsonEncode([
          {
            'generationId': generationId,
            'status': 'completed',
            'templateTitle': 'Trusted local path',
            'templateType': 'image',
            'updatedAtUtc': DateTime.utc(2035).toIso8601String(),
            'previewRemoteUrl': 'https://cdn.petmagic.example/preview.jpg',
            'outputRemoteUrl': 'https://cdn.petmagic.example/output.jpg',
            'previewLocalPath': mediaFile.path,
            'outputLocalPath': mediaFile.path,
            'isDeletedLocally': false,
            'isDownloadComplete': true,
            'lastSyncedAtUtc': DateTime.utc(2035).toIso8601String(),
            'version': 1,
            'pendingServerDelete': false,
            'materializationFailureCount': 0,
            'localBytes': _tinyJpegOne.length,
          },
        ]),
      );
      final store = _store(
        tempDir,
        preferences: preferences,
        session: _sessionForUser(accountScope),
      );

      final items = await store.loadLocalReadyItems();
      final rewritten = await preferences.getString(cacheKey);

      expect(items, hasLength(1));
      expect(items.single.previewLocalPath, mediaFile.path);
      expect(items.single.outputLocalPath, mediaFile.path);
      expect(items.single.isDownloadComplete, isTrue);
      expect(items.single.localBytes, _tinyJpegOne.length);
      expect(rewritten, isNotNull);
      expect(rewritten, isNot(contains(tempDir.path)));
      expect(rewritten, contains('generation_gallery/'));
      expect(rewritten, contains('result_123.jpg'));
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
