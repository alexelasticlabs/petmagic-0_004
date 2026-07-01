import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'template_generation_repository_test_support.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'expired generation cache bucket is discarded and purged from storage',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'templates_generations_v1:user-1:completed',
        jsonEncode([
          generationJson(
            generationId: 'generation-expired',
            status: 'completed',
            updatedAtUtc: '2026-06-14T12:00:00Z',
          ),
        ]),
      );
      await preferences.setString(
        'templates_generations_updated_at_v1:user-1:completed',
        '2026-01-01T00:00:00Z',
      );
      final repository = TemplateGenerationRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://api.petmagic.test')),
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: preferences,
      );

      final cached = await repository.readCachedGenerations(
        status: 'completed',
      );

      expect(cached, isNull);
      expect(
        await preferences.getString(
          'templates_generations_v1:user-1:completed',
        ),
        isNull,
      );
      expect(
        await preferences.getString(
          'templates_generations_updated_at_v1:user-1:completed',
        ),
        isNull,
      );
    },
  );

  test(
    'expired unread generation count is discarded and purged from storage',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setInt('templates_generations_unread_v1:user-1', 4);
      await preferences.setString(
        'templates_generations_unread_updated_at_v1:user-1',
        '2026-01-01T00:00:00Z',
      );
      final repository = TemplateGenerationRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://api.petmagic.test')),
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: preferences,
      );

      final unread = await repository.readCachedUnreadGenerationCount();

      expect(unread, isNull);
      expect(
        await preferences.getInt('templates_generations_unread_v1:user-1'),
        isNull,
      );
      expect(
        await preferences.getString(
          'templates_generations_unread_updated_at_v1:user-1',
        ),
        isNull,
      );
    },
  );

  test('forwards pet photo cancel tokens to every HTTP request', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await safeDeleteTempDir(tempDir);
      }
    });
    final file = await writeTinyJpeg(tempDir, 'pet.jpg');
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        requests.add(options);
        switch (options.path) {
          case '/api/pets/pet-1/photos':
            if (options.method == 'GET') {
              return jsonResponse([petPhotoJson()]);
            }
            return jsonResponse(petPhotoJson());
          case '/api/pets/pet-1/photos/photo-1/set-avatar':
          case '/api/pets/pet-1/photos/photo-1/favorite':
            return jsonResponse(petPhotoJson());
          case '/api/pets/pet-1/photos/photo-1':
            return ResponseBody.fromString('', 204);
        }
        fail('Unexpected request ${options.method} ${options.path}');
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
      preferences: SharedPreferencesAsync(),
    );
    final fetchToken = CancelToken();
    final uploadToken = CancelToken();
    final avatarToken = CancelToken();
    final favoriteToken = CancelToken();
    final deleteToken = CancelToken();

    await repository.fetchPetPhotos('pet-1', cancelToken: fetchToken);
    await repository.uploadPetPhoto(
      petId: 'pet-1',
      photo: XFile(file.path, name: 'pet.jpg'),
      cancelToken: uploadToken,
    );
    await repository.setPetPhotoAsAvatar(
      petId: 'pet-1',
      photoId: 'photo-1',
      cancelToken: avatarToken,
    );
    await repository.setPetPhotoFavorite(
      petId: 'pet-1',
      photoId: 'photo-1',
      isFavorite: true,
      cancelToken: favoriteToken,
    );
    await repository.deletePetPhoto(
      petId: 'pet-1',
      photoId: 'photo-1',
      cancelToken: deleteToken,
    );

    expect(requests.map((request) => request.cancelToken).toList(), [
      fetchToken,
      uploadToken,
      avatarToken,
      favoriteToken,
      deleteToken,
    ]);
  });

  test(
    'mark read skips corrupted cache buckets and updates readable buckets',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'templates_generations_v1:user-1:all',
        '{broken',
      );
      await preferences.setString(
        'templates_generations_v1:user-1:completed',
        jsonEncode([
          generationJson(
            generationId: 'generation-1',
            status: 'completed',
            updatedAtUtc: '2026-06-14T12:00:00Z',
            isUnread: true,
          ),
        ]),
      );
      await preferences.setInt('templates_generations_unread_v1:user-1', 2);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          expect(options.method, 'POST');
          expect(
            options.path,
            '/api/templates/generations/generation-1/mark-read',
          );
          return ResponseBody.fromString('', 204);
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: preferences,
      );

      await repository.markGenerationRead('generation-1');

      final ready = await repository.readCachedGenerations(status: 'completed');
      expect(ready?.single.isUnread, isFalse);
      expect(await repository.readCachedUnreadGenerationCount(), 1);
    },
  );

  test(
    'delete skips corrupted cache buckets and removes readable cached items',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'templates_generations_v1:user-1:all',
        '{broken',
      );
      await preferences.setString(
        'templates_generations_v1:user-1:completed',
        jsonEncode([
          generationJson(
            generationId: 'generation-1',
            status: 'completed',
            updatedAtUtc: '2026-06-14T12:00:00Z',
            isUnread: true,
          ),
        ]),
      );
      await preferences.setInt('templates_generations_unread_v1:user-1', 2);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          expect(options.method, 'DELETE');
          expect(options.path, '/api/templates/generations/generation-1');
          return ResponseBody.fromString('', 204);
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: preferences,
      );

      await repository.deleteGeneration('generation-1');

      final ready = await repository.readCachedGenerations(status: 'completed');
      expect(ready, isEmpty);
      expect(await repository.readCachedUnreadGenerationCount(), 1);
    },
  );

  test(
    'realtime cache upsert keeps persistent filter buckets consistent',
    () async {
      final activeJson = generationJson(
        generationId: 'generation-1',
        status: 'generating',
        updatedAtUtc: '2026-06-14T12:00:00Z',
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          expect(options.path, '/api/templates/generations');
          return switch (options.queryParameters['status'] as String?) {
            'active' => jsonResponse([activeJson]),
            'completed' => jsonResponse([]),
            _ => jsonResponse([activeJson]),
          };
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: SharedPreferencesAsync(),
      );

      await repository.fetchGenerations(take: 50);
      await repository.fetchGenerations(status: 'active', take: 50);
      await repository.fetchGenerations(status: 'completed', take: 50);

      await repository.upsertCachedGeneration(
        TemplateGenerationResult(
          generationId: 'generation-1',
          userId: 'user-1',
          templateId: 'template-1',
          status: TemplateGenerationStatus.completed,
          tokenCost: 6,
          attemptCount: 1,
          createdAtUtc: DateTime.utc(2026, 6, 14, 12),
          updatedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
          userMediaExpired: false,
          outputUrl: 'https://cdn.petmagic.test/generated.jpg',
          completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
          templateTitle: 'Realtime Ready',
          templateType: 'image',
        ),
      );

      final all = await repository.readCachedGenerations();
      final active = await repository.readCachedGenerations(status: 'active');
      final ready = await repository.readCachedGenerations(status: 'completed');

      expect(all?.map((item) => item.generationId), ['generation-1']);
      expect(all?.single.isCompleted, isTrue);
      expect(all?.single.outputUrl, 'https://cdn.petmagic.test/generated.jpg');
      expect(active, isEmpty);
      expect(ready?.map((item) => item.generationId), ['generation-1']);
      expect(ready?.single.isCompleted, isTrue);
    },
  );

  test(
    'realtime cache upsert skips corrupted buckets without breaking others',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'templates_generations_v1:user-1:all',
        '{broken',
      );
      await preferences.setString(
        'templates_generations_v1:user-1:active',
        jsonEncode([
          generationJson(
            generationId: 'generation-1',
            status: 'generating',
            updatedAtUtc: '2026-06-14T12:00:00Z',
          ),
        ]),
      );
      await preferences.setString(
        'templates_generations_v1:user-1:completed',
        '[]',
      );
      final repository = TemplateGenerationRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://api.petmagic.test')),
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: preferences,
      );

      await repository.upsertCachedGeneration(
        TemplateGenerationResult(
          generationId: 'generation-1',
          userId: 'user-1',
          templateId: 'template-1',
          status: TemplateGenerationStatus.completed,
          tokenCost: 6,
          attemptCount: 1,
          createdAtUtc: DateTime.utc(2026, 6, 14, 12),
          updatedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
          userMediaExpired: false,
          outputUrl: 'https://cdn.petmagic.test/generated.jpg',
          completedAtUtc: DateTime.utc(2026, 6, 14, 12, 3),
          templateTitle: 'Realtime Ready',
          templateType: 'image',
        ),
      );

      final active = await repository.readCachedGenerations(status: 'active');
      final ready = await repository.readCachedGenerations(status: 'completed');

      expect(active, isEmpty);
      expect(ready?.map((item) => item.generationId), ['generation-1']);
      expect(ready?.single.isCompleted, isTrue);
    },
  );

  test('generation cache is isolated by account scope', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'templates_generations_v1:user-1:completed',
      jsonEncode([
        generationJson(
          generationId: 'generation-user-1',
          status: 'completed',
          updatedAtUtc: '2026-06-14T12:00:00Z',
        ),
      ]),
    );
    final repository = TemplateGenerationRepository(
      dio: Dio(BaseOptions(baseUrl: 'https://api.petmagic.test')),
      sessionStorage: TestSessionStorage(sessionFixtureFor('user-2')),
      preferences: preferences,
    );

    final cached = await repository.readCachedGenerations(status: 'completed');

    expect(cached, isNull);
  });
}
