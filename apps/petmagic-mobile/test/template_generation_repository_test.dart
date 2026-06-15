import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('sanitizes source image multipart filename without path fragments', () {
    final source = File(
      'lib/features/templates/data/template_generation_repository.dart',
    ).readAsStringSync();
    final startBody = _methodBody(source, 'startGeneration');
    final filenameBody = _methodBody(source, '_safeSourceImageFileName');

    expect(startBody, contains('_safeSourceImageFileName(rawFileName)'));
    expect(startBody, contains('filename: fileName'));
    expect(filenameBody, contains("replaceAll(r'\\', '/')"));
    expect(filenameBody, contains("split('/')"));
    expect(filenameBody, contains('sanitizeFileName('));
    expect(filenameBody, contains('petmagic_source_image.jpg'));
    expect(startBody, contains('authenticatedMultipartRequestOptions('));
  });

  test('keeps pet generation and pet profile request contracts stable', () {
    final source = File(
      'lib/features/templates/data/template_generation_repository.dart',
    ).readAsStringSync();
    final fromPetBody = _methodBody(source, 'startGenerationFromPet');
    final createPetBody = _methodBody(source, 'createPet');
    final updatePetBody = _methodBody(source, 'updatePet');

    expect(fromPetBody, contains("'/api/generations/from-pet'"));
    expect(fromPetBody, contains("'Idempotency-Key': idempotencyKey"));
    expect(fromPetBody, contains("'petId': petId"));
    expect(fromPetBody, contains("'templateId': templateId"));
    expect(
      fromPetBody,
      contains("if (petPhotoId != null && petPhotoId.isNotEmpty)"),
    );
    expect(fromPetBody, contains("'petPhotoId': petPhotoId"));
    expect(fromPetBody, contains('retryTransientFailures: false'));

    expect(createPetBody, contains("'breed': ?breed"));
    expect(updatePetBody, contains("'breed': ?breed"));
  });

  test('maps canonical mediaUrl generation field to outputUrl', () {
    final dto = TemplateGenerationDto.fromJson({
      'generationId': 'generation-1',
      'userId': 'user-1',
      'templateId': 'template-1',
      'status': 'Succeeded',
      'tokenCost': 1,
      'attemptCount': 1,
      'createdAtUtc': '2026-06-14T12:00:00Z',
      'updatedAtUtc': '2026-06-14T12:01:00Z',
      'mediaUrl': 'https://cdn.petmagic.test/result.png?signature=test',
    });

    expect(
      dto.toDomain().outputUrl,
      'https://cdn.petmagic.test/result.png?signature=test',
    );
  });

  test(
    'rejects missing source image without exposing local file path',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final repository = TemplateGenerationRepository(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );
      final missingPath = '${tempDir.path}/missing-pet.jpg';

      await expectLater(
        repository.startGeneration(
          templateId: 'template-1',
          sourceImage: XFile(missingPath, name: 'missing-pet.jpg'),
        ),
        throwsA(
          isA<AppException>()
              .having(
                (error) => error.message,
                'message',
                'templates.source_image_unavailable',
              )
              .having(
                (error) => error.toString(),
                'toString',
                isNot(contains(tempDir.path)),
              ),
        ),
      );
    },
  );

  test('rejects spoofed source image content before upload', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}/spoofed-pet.jpg');
    await file.writeAsBytes('%PDF-1.7 not an image'.codeUnits, flush: true);
    var didAttemptUpload = false;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            didAttemptUpload = true;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: AuthSessionStorage(),
      preferences: SharedPreferencesAsync(),
    );

    await expectLater(
      repository.startGeneration(
        templateId: 'template-1',
        sourceImage: XFile(
          file.path,
          name: 'spoofed-pet.jpg',
          mimeType: 'image/jpeg',
        ),
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'templates.source_image_type_not_allowed',
        ),
      ),
    );

    expect(didAttemptUpload, isFalse);
  });

  test('rejects spoofed pet photo content before upload', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}/spoofed-pet.jpg');
    await file.writeAsBytes('%PDF-1.7 not an image'.codeUnits, flush: true);
    var didAttemptUpload = false;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            didAttemptUpload = true;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: AuthSessionStorage(),
      preferences: SharedPreferencesAsync(),
    );

    await expectLater(
      repository.uploadPetPhoto(
        petId: 'pet-1',
        photo: XFile(
          file.path,
          name: 'spoofed-pet.jpg',
          mimeType: 'image/jpeg',
        ),
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'pets.photo_type_not_allowed',
        ),
      ),
    );

    expect(didAttemptUpload, isFalse);
  });

  test('rejects missing pet photo without exposing local file path', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    var didAttemptUpload = false;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            didAttemptUpload = true;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: AuthSessionStorage(),
      preferences: SharedPreferencesAsync(),
    );
    final missingPath = '${tempDir.path}/missing-pet.jpg';

    await expectLater(
      repository.uploadPetPhoto(
        petId: 'pet-1',
        photo: XFile(missingPath, name: 'missing-pet.jpg'),
      ),
      throwsA(
        isA<AppException>()
            .having(
              (error) => error.message,
              'message',
              'pets.photo_type_not_allowed',
            )
            .having(
              (error) => error.toString(),
              'toString',
              isNot(contains(tempDir.path)),
            ),
      ),
    );

    expect(didAttemptUpload, isFalse);
  });

  test('rejects declared non-image pet photo content before upload', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = await _writeTinyJpeg(tempDir, 'pet.txt');
    var didAttemptUpload = false;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            didAttemptUpload = true;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: AuthSessionStorage(),
      preferences: SharedPreferencesAsync(),
    );

    await expectLater(
      repository.uploadPetPhoto(
        petId: 'pet-1',
        photo: XFile(file.path, name: 'pet.txt', mimeType: 'text/plain'),
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'pets.photo_type_not_allowed',
        ),
      ),
    );

    expect(didAttemptUpload, isFalse);
  });

  test('uploads pet photos as multipart with detected content type', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = await _writeTinyJpeg(tempDir, 'pet.jpg');

    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        requestCount++;
        expect(options.method, 'POST');
        expect(options.path, '/api/pets/pet-1/photos');
        expect(
          options.headers[HttpHeaders.authorizationHeader],
          'Bearer access-token',
        );
        expect(options.data, isA<FormData>());

        final formData = options.data as FormData;
        expect(formData.files, hasLength(1));
        final entry = formData.files.single;
        expect(entry.key, 'photo');
        expect(entry.value.filename, 'pet.jpg');
        expect(entry.value.contentType.toString(), 'image/jpeg');

        return _jsonResponse(_petPhotoJson());
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: _SessionStorage(_session()),
      preferences: SharedPreferencesAsync(),
    );

    final photo = await repository.uploadPetPhoto(
      petId: 'pet-1',
      photo: XFile(file.path, name: 'pet.jpg', mimeType: 'image/png'),
    );

    expect(requestCount, 1);
    expect(photo.id, 'photo-1');
    expect(photo.thumbnailUrl, 'https://cdn.petmagic.test/photo-1-thumb.jpg');
    expect(photo.contentType, 'image/jpeg');
  });

  test('keeps pet photo CRUD request contracts stable', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        requests.add(options);
        switch (options.path) {
          case '/api/pets/pet-1/photos':
            return _jsonResponse([_petPhotoJson()]);
          case '/api/pets/pet-1/photos/photo-1/set-avatar':
          case '/api/pets/pet-1/photos/photo-1/favorite':
            return _jsonResponse(_petPhotoJson());
          case '/api/pets/pet-1/photos/photo-1':
            return ResponseBody.fromString('', 204);
        }
        fail('Unexpected request ${options.method} ${options.path}');
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: _SessionStorage(_session()),
      preferences: SharedPreferencesAsync(),
    );

    final photos = await repository.fetchPetPhotos('pet-1');
    final avatar = await repository.setPetPhotoAsAvatar(
      petId: 'pet-1',
      photoId: 'photo-1',
    );
    final favorite = await repository.setPetPhotoFavorite(
      petId: 'pet-1',
      photoId: 'photo-1',
      isFavorite: true,
    );
    await repository.deletePetPhoto(petId: 'pet-1', photoId: 'photo-1');

    expect(photos.single.id, 'photo-1');
    expect(avatar.id, 'photo-1');
    expect(favorite.id, 'photo-1');
    expect(
      requests.map((request) => '${request.method} ${request.path}').toList(),
      [
        'GET /api/pets/pet-1/photos',
        'POST /api/pets/pet-1/photos/photo-1/set-avatar',
        'POST /api/pets/pet-1/photos/photo-1/favorite',
        'DELETE /api/pets/pet-1/photos/photo-1',
      ],
    );
    expect(requests[2].data, {'isFavorite': true});
    for (final request in requests) {
      expect(
        request.headers[HttpHeaders.authorizationHeader],
        'Bearer access-token',
      );
    }
  });

  test('encodes pet photo API path segments', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = await _writeTinyJpeg(tempDir, 'pet.jpg');
    const petId = 'pet/space id?x=1';
    const photoId = 'photo/1?star=true';
    final encodedPetId = Uri.encodeComponent(petId);
    final encodedPhotoId = Uri.encodeComponent(photoId);
    final expectedPaths = [
      '/api/pets/$encodedPetId',
      '/api/pets/$encodedPetId',
      '/api/pets/$encodedPetId/photos',
      '/api/pets/$encodedPetId/photos',
      '/api/pets/$encodedPetId/photos/$encodedPhotoId/set-avatar',
      '/api/pets/$encodedPetId/photos/$encodedPhotoId/favorite',
      '/api/pets/$encodedPetId/photos/$encodedPhotoId',
      '/api/pets/$encodedPetId/generations',
    ];
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        requests.add(options);
        final expectedPath = expectedPaths[requests.length - 1];
        expect(options.path, expectedPath);
        return switch (requests.length) {
          1 => _jsonResponse(_petJson(id: petId)),
          2 => ResponseBody.fromString('', 204),
          3 => _jsonResponse(_petPhotoJson()),
          4 => _jsonResponse([_petPhotoJson()]),
          5 => _jsonResponse(_petPhotoJson()),
          6 => _jsonResponse(_petPhotoJson()),
          7 => ResponseBody.fromString('', 204),
          8 => _jsonResponse([
            _generationJson(
              generationId: 'generation-1',
              status: 'completed',
              updatedAtUtc: '2026-06-14T12:00:00Z',
            ),
          ]),
          _ => fail('Unexpected request ${options.method} ${options.path}'),
        };
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: _SessionStorage(_session()),
      preferences: SharedPreferencesAsync(),
    );

    await repository.updatePet(petId: petId, name: 'Bella', type: 'dog');
    await repository.deletePet(petId);
    await repository.uploadPetPhoto(
      petId: petId,
      photo: XFile(file.path, name: 'pet.jpg'),
    );
    await repository.fetchPetPhotos(petId);
    await repository.setPetPhotoAsAvatar(petId: petId, photoId: photoId);
    await repository.setPetPhotoFavorite(
      petId: petId,
      photoId: photoId,
      isFavorite: true,
    );
    await repository.deletePetPhoto(petId: petId, photoId: photoId);
    await repository.fetchPetGenerations(petId);

    expect(requests.map((request) => request.path).toList(), expectedPaths);
  });

  test('encodes generation API path segments', () async {
    const generationId = 'generation/space id?x=1';
    const resultId = 'result/1?compatible=true';
    const sourceGenerationId = 'source/1?similar=true';
    const nextGenerationId = 'next generation/1?status=true';
    const templateId = 'template/1?event=true';
    final encodedGenerationId = Uri.encodeComponent(generationId);
    final encodedResultId = Uri.encodeComponent(resultId);
    final encodedSourceGenerationId = Uri.encodeComponent(sourceGenerationId);
    final encodedNextGenerationId = Uri.encodeComponent(nextGenerationId);
    final encodedTemplateId = Uri.encodeComponent(templateId);
    final expectedRequests = [
      'GET /api/generations/$encodedGenerationId',
      'GET /api/generation-results/$encodedResultId/compatible-templates',
      'POST /api/generations/$encodedSourceGenerationId/generate-similar',
      'GET /api/generations/$encodedNextGenerationId',
      'POST /api/generations/$encodedGenerationId/remove-watermark',
      'POST /api/templates/$encodedTemplateId/analytics/events',
      'POST /api/templates/$encodedTemplateId/analytics/events',
      'GET /api/generations/$encodedGenerationId/download',
      'POST /api/generations/$encodedGenerationId/share',
      'POST /api/templates/generations/$encodedGenerationId/mark-read',
      'DELETE /api/templates/generations/$encodedGenerationId',
    ];
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        requests.add(options);
        expect(
          '${options.method} ${options.path}',
          expectedRequests[requests.length - 1],
        );
        return switch (requests.length) {
          1 => _jsonResponse(
            _generationJson(
              generationId: generationId,
              status: 'completed',
              updatedAtUtc: '2026-06-14T12:00:00Z',
            ),
          ),
          2 => _jsonResponse({
            'resultId': resultId,
            'inputMediaType': 'image',
            'templates': [],
          }),
          3 => _jsonResponse({'generationId': nextGenerationId}),
          4 => _jsonResponse(
            _generationJson(
              generationId: nextGenerationId,
              status: 'completed',
              updatedAtUtc: '2026-06-14T12:01:00Z',
            ),
          ),
          5 => _jsonResponse({'watermarkRemoved': true, 'creditsSpent': 1}),
          6 || 7 || 10 || 11 => ResponseBody.fromString('', 204),
          8 || 9 => _jsonResponse({
            'mediaUrl': 'https://cdn.petmagic.test/generated.jpg',
            'hasWatermark': false,
            'fileName': 'generated.jpg',
          }),
          _ => fail('Unexpected request ${options.method} ${options.path}'),
        };
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: _SessionStorage(_session()),
      preferences: SharedPreferencesAsync(),
    );

    final generation = await repository.fetchGeneration(generationId);
    final compatible = await repository.fetchCompatibleTemplates(resultId);
    final similar = await repository.generateSimilar(
      sourceGenerationId: sourceGenerationId,
    );
    final watermark = await repository.removeWatermark(generationId);
    await repository.recordTemplateAnalyticsEvent(
      templateId: templateId,
      eventType: 'preview_opened',
      source: 'gallery',
      generationId: generationId,
    );
    await repository.recordAnalyticsEvent(
      templateId: templateId,
      eventType: 'card_tapped',
      generationId: generationId,
    );
    final download = await repository.fetchDownloadUrl(generationId);
    final share = await repository.fetchShareUrl(generationId);
    await repository.markGenerationRead(generationId);
    await repository.deleteGeneration(generationId);

    expect(generation.generationId, generationId);
    expect(compatible.resultId, resultId);
    expect(similar.generationId, nextGenerationId);
    expect(watermark.watermarkRemoved, isTrue);
    expect(download.mediaUrl, 'https://cdn.petmagic.test/generated.jpg');
    expect(share.fileName, 'generated.jpg');
    expect(
      requests.map((request) => '${request.method} ${request.path}').toList(),
      expectedRequests,
    );
    expect(requests[5].data, containsPair('generationId', generationId));
    expect(requests[6].data, containsPair('generationId', generationId));
  });

  test('forwards pet photo cancel tokens to every HTTP request', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = await _writeTinyJpeg(tempDir, 'pet.jpg');
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        requests.add(options);
        switch (options.path) {
          case '/api/pets/pet-1/photos':
            if (options.method == 'GET') {
              return _jsonResponse([_petPhotoJson()]);
            }
            return _jsonResponse(_petPhotoJson());
          case '/api/pets/pet-1/photos/photo-1/set-avatar':
          case '/api/pets/pet-1/photos/photo-1/favorite':
            return _jsonResponse(_petPhotoJson());
          case '/api/pets/pet-1/photos/photo-1':
            return ResponseBody.fromString('', 204);
        }
        fail('Unexpected request ${options.method} ${options.path}');
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: _SessionStorage(_session()),
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
    'realtime cache upsert keeps persistent filter buckets consistent',
    () async {
      final activeJson = _generationJson(
        generationId: 'generation-1',
        status: 'generating',
        updatedAtUtc: '2026-06-14T12:00:00Z',
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          expect(options.path, '/api/templates/generations');
          return switch (options.queryParameters['status'] as String?) {
            'active' => _jsonResponse([activeJson]),
            'ready' => _jsonResponse([]),
            _ => _jsonResponse([activeJson]),
          };
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: _SessionStorage(_session()),
        preferences: SharedPreferencesAsync(),
      );

      await repository.fetchGenerations(take: 50);
      await repository.fetchGenerations(status: 'active', take: 50);
      await repository.fetchGenerations(status: 'ready', take: 50);

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
      final ready = await repository.readCachedGenerations(status: 'ready');

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
      await preferences.setString('templates_generations_v1:all', '{broken');
      await preferences.setString(
        'templates_generations_v1:active',
        jsonEncode([
          _generationJson(
            generationId: 'generation-1',
            status: 'generating',
            updatedAtUtc: '2026-06-14T12:00:00Z',
          ),
        ]),
      );
      await preferences.setString('templates_generations_v1:ready', '[]');
      final repository = TemplateGenerationRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://api.petmagic.test')),
        sessionStorage: _SessionStorage(_session()),
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
      final ready = await repository.readCachedGenerations(status: 'ready');

      expect(active, isEmpty);
      expect(ready?.map((item) => item.generationId), ['generation-1']);
      expect(ready?.single.isCompleted, isTrue);
    },
  );
}

Future<File> _writeTinyJpeg(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(const [
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
  ], flush: true);
  return file;
}

ResponseBody _jsonResponse(Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _petPhotoJson() {
  return {
    'id': 'photo-1',
    'petId': 'pet-1',
    'mediaAssetId': 'asset-1',
    'url': 'https://cdn.petmagic.test/photo-1.jpg',
    'thumbnailUrl': 'https://cdn.petmagic.test/photo-1-thumb.jpg',
    'fileName': 'pet.jpg',
    'contentType': 'image/jpeg',
    'fileSizeBytes': 14,
    'isFavorite': false,
    'isAvatar': false,
    'sortOrder': 0,
    'createdAtUtc': '2026-06-14T12:00:00Z',
  };
}

Map<String, dynamic> _petJson({String id = 'pet-1'}) {
  return {
    'id': id,
    'name': 'Bella',
    'type': 'dog',
    'photosCount': 1,
    'generationsCount': 0,
    'createdAtUtc': '2026-06-14T12:00:00Z',
    'updatedAtUtc': '2026-06-14T12:00:00Z',
  };
}

Map<String, dynamic> _generationJson({
  required String generationId,
  required String status,
  required String updatedAtUtc,
}) {
  return {
    'generationId': generationId,
    'userId': 'user-1',
    'templateId': 'template-1',
    'status': status,
    'tokenCost': 6,
    'attemptCount': 1,
    'createdAtUtc': '2026-06-14T12:00:00Z',
    'updatedAtUtc': updatedAtUtc,
    'userMediaExpired': false,
    'templateTitle': 'Realtime Active',
    'templateType': 'image',
    'isUnread': true,
  };
}

AuthSession _session() {
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    user: const MobileUserProfile(
      userId: 'user-1',
      email: 'pet@example.com',
      displayName: 'Pet Parent',
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: false,
      legalAcceptance: _legalAcceptance,
      roles: ['user'],
      avatar: null,
    ),
  );
}

const _legalAcceptance = MobileLegalAcceptanceStatus(
  termsOfUseAccepted: true,
  termsOfUseAcceptedVersion: '2026-05-20',
  termsOfUseAcceptedAtUtc: null,
  privacyPolicyAccepted: true,
  privacyPolicyAcceptedVersion: '2026-05-20',
  privacyPolicyAcceptedAtUtc: null,
  currentTermsOfUseVersion: '2026-05-20',
  currentPrivacyPolicyVersion: '2026-05-20',
  requiresAcceptance: false,
);

class _SessionStorage extends AuthSessionStorage {
  _SessionStorage(this._session);

  final AuthSession _session;

  @override
  Future<AuthSession?> read() async => _session;
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:Future<[^>]+>|String)\s+' + methodName + r'\s*\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = _methodOpenBraceIndex(source, methodMatch);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
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
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
}

int _methodOpenBraceIndex(String source, RegExpMatch methodMatch) {
  var parenDepth = 0;
  for (var index = methodMatch.end - 1; index < source.length; index++) {
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
      return index;
    }
  }

  return -1;
}
