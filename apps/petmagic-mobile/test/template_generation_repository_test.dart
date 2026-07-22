import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'template_generation_repository_test_support.dart';

Future<void> _safeDeleteTempDir(Directory dir) async {
  if (!await dir.exists()) return;
  for (var i = 0; i < 3; i++) {
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      if (i < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('sanitizes source image multipart filename without path fragments', () {
    final uploadSource = File(
      'lib/features/templates/data/generation_source_upload_preparer.dart',
    ).readAsStringSync();
    final transportSource = File(
      'lib/features/templates/data/generation_remote_data_source.dart',
    ).readAsStringSync();
    final supportSource = File(
      'lib/features/templates/data/template_image_upload_support.dart',
    ).readAsStringSync();
    final prepareBody = methodBody(uploadSource, 'prepare');
    final startBody = methodBody(transportSource, 'startGeneration');
    final filenameBody = methodBody(supportSource, 'safeFileName');

    expect(prepareBody, contains('_fileName(sourceImage.name'));
    expect(prepareBody, contains('_fileName(uploadFile.name'));
    expect(startBody, contains('filename: prepared.fileName'));
    expect(filenameBody, contains("replaceAll(r'\\', '/')"));
    expect(filenameBody, contains("split('/')"));
    expect(filenameBody, contains('sanitizeFileName('));
    expect(filenameBody, contains('petmagic_source_image.jpg'));
    expect(startBody, contains('authenticatedMultipartRequestOptions('));
  });

  test('keeps pet generation and pet profile request contracts stable', () {
    final generationSource = File(
      'lib/features/templates/data/generation_remote_data_source.dart',
    ).readAsStringSync();
    final petSource = File(
      'lib/features/templates/data/pet_profile_remote_data_source.dart',
    ).readAsStringSync();
    final fromPetBody = methodBody(generationSource, 'startGenerationFromPet');
    final createPetBody = methodBody(petSource, 'createPet');
    final updatePetBody = methodBody(petSource, 'updatePet');

    expect(fromPetBody, contains("'/api/templates/generations/from-pet'"));
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

  test(
    'startGenerationFromPet sends raw pet and photo IDs in request body',
    () async {
      const petId = 'pet/space #1?x=1&kind=dog';
      const petPhotoId = 'photo/primary #7?pose=1&tag=a';
      const templateId = 'template/pet portrait #1';
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          requests.add(options);
          expect(options.method, 'POST');
          expect(options.path, '/api/templates/generations/from-pet');
          expect(
            options.headers[HttpHeaders.authorizationHeader],
            'Bearer access-token',
          );
          expect(options.headers['X-Correlation-Id'], 'corr-1');
          expect(options.headers['Idempotency-Key'], isNotNull);
          expect(options.data, {
            'petId': petId,
            'petPhotoId': petPhotoId,
            'templateId': templateId,
          });
          return jsonResponse({
            ...generationJson(
              generationId: 'generation-from-pet',
              status: 'queued',
              updatedAtUtc: '2026-06-14T12:01:00Z',
            ),
            'templateId': templateId,
            'petId': petId,
            'petPhotoId': petPhotoId,
          });
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: SharedPreferencesAsync(),
      );

      final generation = await repository.startGenerationFromPet(
        petId: petId,
        petPhotoId: petPhotoId,
        templateId: templateId,
        correlationId: 'corr-1',
      );

      expect(requests, hasLength(1));
      expect(generation.generationId, 'generation-from-pet');
      expect(generation.petId, petId);
      expect(generation.petPhotoId, petPhotoId);
      expect(generation.templateId, templateId);
    },
  );

  test('startGeneration encodes template ID path segment', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await _safeDeleteTempDir(tempDir);
      }
    });
    final file = await writeTinyJpeg(tempDir, 'source.jpg');
    const templateId = 'template/space #1?x=1&kind=pet';
    final encodedTemplateId = Uri.encodeComponent(templateId);
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        requests.add(options);
        expect(options.method, 'POST');
        expect(options.path, '/api/templates/$encodedTemplateId/generations');
        expect(
          options.headers[HttpHeaders.authorizationHeader],
          'Bearer access-token',
        );
        expect(options.headers['X-Correlation-Id'], 'corr-1');
        expect(options.data, isA<FormData>());

        final formData = options.data as FormData;
        expect(formData.files.single.key, 'sourceImage');
        expect(formData.files.single.value.filename, 'source.jpg');
        expect(
          formData.files.single.value.contentType.toString(),
          'image/jpeg',
        );
        return jsonResponse({
          ...generationJson(
            generationId: 'generation-template-route',
            status: 'queued',
            updatedAtUtc: '2026-06-14T12:01:00Z',
          ),
          'templateId': templateId,
        });
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
      preferences: SharedPreferencesAsync(),
    );

    final generation = await repository.startGeneration(
      templateId: templateId,
      sourceImage: LocalMediaFile(path: file.path, name: 'source.jpg'),
      correlationId: 'corr-1',
    );

    expect(requests, hasLength(1));
    expect(generation.generationId, 'generation-template-route');
    expect(generation.templateId, templateId);
  });

  test('uploads generation source from optimized temp payloads', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-generation-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await _safeDeleteTempDir(tempDir);
      }
    });
    final source = await writeTinyJpeg(tempDir, 'source.jpg');
    final optimized = await writeTinyJpeg(tempDir, 'optimized-source.jpg');
    String? uploadedFileName;
    String? uploadedContentType;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        final formData = options.data as FormData;
        uploadedFileName = formData.files.single.value.filename;
        uploadedContentType = formData.files.single.value.contentType
            .toString();
        return jsonResponse(
          generationJson(
            generationId: 'generation-optimized-source',
            status: 'queued',
            updatedAtUtc: '2026-06-14T12:01:00Z',
          ),
        );
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
      preferences: SharedPreferencesAsync(),
      imageUploadOptimizer: FakeImageUploadOptimizer(
        generationSource: optimized,
      ),
    );

    await repository.startGeneration(
      templateId: 'template-1',
      sourceImage: LocalMediaFile(
        path: source.path,
        name: 'source.bin',
        mimeType: 'image/png',
      ),
    );

    expect(uploadedFileName, 'optimized-source.jpg');
    expect(uploadedContentType, 'image/jpeg');
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

  test('parses queue metadata and cancelled status as terminal', () {
    final dto = TemplateGenerationDto.fromJson({
      'generationId': 'generation-queue-1',
      'userId': 'user-1',
      'templateId': 'template-video-1',
      'status': 'Cancelled',
      'tokenCost': 10,
      'attemptCount': 1,
      'createdAtUtc': '2026-06-14T12:00:00Z',
      'updatedAtUtc': '2026-06-14T12:01:00Z',
      'mediaType': 'video',
      'tier': 'free',
      'queuePosition': 4,
      'estimatedWaitSeconds': 420,
      'estimatedTotalSeconds': 540,
      'estimatedCompletionAtUtc': '2026-06-14T12:09:00Z',
      'queueStatus': 'queued',
      'canCancel': false,
    });

    final generation = dto.toDomain();

    expect(generation.status, TemplateGenerationStatus.cancelled);
    expect(generation.isTerminal, isTrue);
    expect(generation.isCancelled, isTrue);
    expect(generation.mediaType, 'video');
    expect(generation.tier, 'free');
    expect(generation.queuePosition, 4);
    expect(generation.estimatedWaitSeconds, 420);
    expect(generation.estimatedTotalSeconds, 540);
    expect(
      generation.estimatedCompletionAtUtc,
      DateTime.utc(2026, 6, 14, 12, 9),
    );
    expect(generation.queueStatus, 'queued');
    expect(generation.canCancelQueued, isFalse);
  });

  test('parses legacy generation responses without queue metadata', () {
    final dto = TemplateGenerationDto.fromJson(
      generationJson(
        generationId: 'generation-legacy-1',
        status: 'Processing',
        updatedAtUtc: '2026-06-14T12:01:00Z',
      ),
    );

    final generation = dto.toDomain();

    expect(generation.status, TemplateGenerationStatus.processing);
    expect(generation.queuePosition, isNull);
    expect(generation.estimatedWaitSeconds, isNull);
    expect(generation.estimatedCompletionAtUtc, isNull);
    expect(generation.estimatedTotalSeconds, isNull);
    expect(generation.mediaType, isNull);
    expect(generation.tier, isNull);
    expect(generation.queueStatus, isNull);
    expect(generation.canCancelQueued, isFalse);
  });

  test(
    'parses async provider and cancellation statuses as active non-cancellable states',
    () {
      final cases = {
        'SubmittingToProvider': TemplateGenerationStatus.submittingToProvider,
        'ProviderQueued': TemplateGenerationStatus.providerQueued,
        'ProviderProcessing': TemplateGenerationStatus.providerProcessing,
        'ImportingMedia': TemplateGenerationStatus.importingMedia,
        'CancellationRequested': TemplateGenerationStatus.cancellationRequested,
        '7': TemplateGenerationStatus.submittingToProvider,
        '8': TemplateGenerationStatus.providerQueued,
        '9': TemplateGenerationStatus.providerProcessing,
        '10': TemplateGenerationStatus.importingMedia,
        '11': TemplateGenerationStatus.cancellationRequested,
      };

      for (final entry in cases.entries) {
        final generation = TemplateGenerationDto.fromJson(
          generationJson(
            generationId: 'generation-${entry.key}',
            status: entry.key,
            updatedAtUtc: '2026-06-14T12:01:00Z',
          ),
        ).toDomain();

        expect(generation.status, entry.value);
        expect(generation.isTerminal, isFalse);
        expect(generation.canCancelQueued, isFalse);
      }
    },
  );

  test(
    'maps GENERATION_WAIT_TOO_LONG response to structured exception',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          expect(options.path, '/api/templates/generations/from-pet');
          return jsonResponse({
            'code': 'GENERATION_WAIT_TOO_LONG',
            'mediaType': 'video',
            'tier': 'free',
            'estimatedWaitSeconds': 1800,
            'maxAllowedWaitSeconds': 1200,
            'retryAfterSeconds': 300,
            'canRetry': true,
            'canUpgradeForPriority': true,
          }, statusCode: 503);
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(
        repository.startGenerationFromPet(
          petId: 'pet-1',
          templateId: 'template-video-1',
        ),
        throwsA(
          isA<GenerationWaitTooLongException>()
              .having((error) => error.mediaType, 'mediaType', 'video')
              .having((error) => error.tier, 'tier', 'free')
              .having(
                (error) => error.estimatedWaitSeconds,
                'estimatedWaitSeconds',
                1800,
              )
              .having(
                (error) => error.retryAfterSeconds,
                'retryAfterSeconds',
                300,
              )
              .having(
                (error) => error.canUpgradeForPriority,
                'canUpgradeForPriority',
                isTrue,
              )
              .having(
                (error) => error.message,
                'message',
                'templates.generation_wait_too_long',
              ),
        ),
      );
    },
  );

  test(
    'maps 503 wait metadata to structured exception when code is generic',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          return jsonResponse({
            'code': 'INTERNAL_SERVER_ERROR',
            'mediaType': 'video',
            'tier': 'free',
            'estimatedWaitSeconds': 4200,
            'maxAllowedWaitSeconds': 3600,
            'retryAfterSeconds': 300,
            'canRetry': true,
            'canUpgradeForPriority': true,
          }, statusCode: 503);
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(
        repository.startGenerationFromPet(
          petId: 'pet-1',
          templateId: 'template-video-1',
        ),
        throwsA(
          isA<GenerationWaitTooLongException>()
              .having((error) => error.mediaType, 'mediaType', 'video')
              .having((error) => error.tier, 'tier', 'free')
              .having(
                (error) => error.estimatedWaitSeconds,
                'estimatedWaitSeconds',
                4200,
              )
              .having(
                (error) => error.maxAllowedWaitSeconds,
                'maxAllowedWaitSeconds',
                3600,
              )
              .having(
                (error) => error.canUpgradeForPriority,
                'canUpgradeForPriority',
                isTrue,
              ),
        ),
      );
    },
  );

  test(
    'cancelGeneration posts cancel endpoint and parses refund result',
    () async {
      const generationId = 'generation/queued 1?x=true';
      final encodedGenerationId = Uri.encodeComponent(generationId);
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          capturedOptions = options;
          expect(options.method, 'POST');
          expect(
            options.path,
            '/api/templates/generations/$encodedGenerationId/cancel',
          );
          expect(options.headers['X-Correlation-Id'], 'corr-cancel');
          return jsonResponse({
            'generation': generationJson(
              generationId: generationId,
              status: 'Cancelled',
              updatedAtUtc: '2026-06-14T12:05:00Z',
            ),
            'refunded': true,
            'cancelledAtUtc': '2026-06-14T12:05:00Z',
          });
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: SharedPreferencesAsync(),
      );

      final result = await repository.cancelGeneration(
        generationId,
        correlationId: 'corr-cancel',
      );

      expect(capturedOptions, isNotNull);
      expect(result.refunded, isTrue);
      expect(result.generation.status, TemplateGenerationStatus.cancelled);
      expect(result.generation.isTerminal, isTrue);
      expect(result.cancelledAtUtc, DateTime.utc(2026, 6, 14, 12, 5));
    },
  );

  test(
    'readActiveGeneration migrates missing correlation id in persisted state',
    () async {
      final preferences = SharedPreferencesAsync();
      final secureStorage = _FakeSecureStorage();
      await preferences.setString(
        'templates_active_generation_id_v1:user-1',
        'generation-1',
      );

      final repository = TemplateGenerationRepository(
        dio: Dio(),
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: preferences,
        secureStorage: secureStorage,
      );

      final restored = await repository.readActiveGeneration();

      expect(restored?.generationId, 'generation-1');
      expect(restored?.correlationId, startsWith('generation-'));

      expect(
        await preferences.getString('templates_active_generation_id_v1:user-1'),
        isNull,
      );
      final keys = await preferences.getKeys();
      expect(keys.any((key) => key.contains('user-1')), isFalse);
      expect(
        keys.any(
          (key) =>
              key.startsWith('templates_active_generation_correlation_id_v1:'),
        ),
        isFalse,
      );
      expect(secureStorage.values.values, contains('generation-1'));
      expect(secureStorage.values.values, contains(restored?.correlationId));
    },
  );

  test('generation correlation ids use shared request identity fallback', () {
    final repositorySource = File(
      'lib/features/templates/data/template_generation_repository.dart',
    ).readAsStringSync();
    final controllerSource = [
      'lib/features/templates/presentation/template_generation_controller.dart',
      'lib/features/templates/presentation/template_generation_policy.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(repositorySource, contains('request_identity.dart'));
    expect(repositorySource, contains('RequestIdentity.createCorrelationId()'));
    expect(controllerSource, contains('RequestIdentity.createCorrelationId()'));
    expect(repositorySource, isNot(contains('Random.secure()')));
    expect(controllerSource, isNot(contains('Random.secure()')));
  });

  test(
    'rejects missing source image without exposing local file path',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await _safeDeleteTempDir(tempDir);
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
          sourceImage: LocalMediaFile(
            path: missingPath,
            name: 'missing-pet.jpg',
          ),
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
        await _safeDeleteTempDir(tempDir);
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
        sourceImage: LocalMediaFile(
          path: file.path,
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

  test(
    'rejects spoofed generation source before optimizer can replace payload',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-generation-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await _safeDeleteTempDir(tempDir);
        }
      });
      final source = File('${tempDir.path}/source.jpg');
      await source.writeAsBytes('%PDF-1.7 not an image'.codeUnits, flush: true);
      final optimized = await writeTinyJpeg(tempDir, 'optimized-source.jpg');
      final optimizer = FakeImageUploadOptimizer(generationSource: optimized);
      var didAttemptUpload = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          didAttemptUpload = true;
          return jsonResponse(
            generationJson(
              generationId: 'generation-spoofed-source',
              status: 'queued',
              updatedAtUtc: '2026-06-14T12:01:00Z',
            ),
          );
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: SharedPreferencesAsync(),
        imageUploadOptimizer: optimizer,
      );

      await expectLater(
        repository.startGeneration(
          templateId: 'template-1',
          sourceImage: LocalMediaFile(
            path: source.path,
            name: 'source.jpg',
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
      expect(optimizer.generationSourceOptimizeCalls, 0);
    },
  );

  test('rejects spoofed pet photo content before upload', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await _safeDeleteTempDir(tempDir);
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
        await _safeDeleteTempDir(tempDir);
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
        await _safeDeleteTempDir(tempDir);
      }
    });

    final file = await writeTinyJpeg(tempDir, 'pet.txt');
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

  test('sniffs pet photos with generic binary picker content type', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await _safeDeleteTempDir(tempDir);
      }
    });
    final file = await writeTinyJpeg(tempDir, 'pet.jpg');

    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        requestCount++;
        expect(options.method, 'POST');
        expect(options.path, '/api/pets/pet-1/photos');
        expect(options.data, isA<FormData>());

        final formData = options.data as FormData;
        expect(formData.files, hasLength(1));
        final entry = formData.files.single;
        expect(entry.key, 'photo');
        expect(entry.value.filename, 'pet.jpg');
        expect(entry.value.contentType.toString(), 'image/jpeg');

        return jsonResponse(petPhotoJson());
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
      preferences: SharedPreferencesAsync(),
    );

    final photo = await repository.uploadPetPhoto(
      petId: 'pet-1',
      photo: XFile(
        file.path,
        name: 'pet.jpg',
        mimeType: 'application/octet-stream',
      ),
    );

    expect(requestCount, 1);
    expect(photo.contentType, 'image/jpeg');
  });

  test('uploads pet photos as multipart with detected content type', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await _safeDeleteTempDir(tempDir);
      }
    });
    final file = await writeTinyJpeg(tempDir, 'pet.jpg');

    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
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

        return jsonResponse(petPhotoJson());
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
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

  test('uploads HEIC and HEIF pet photos with detected content type', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await _safeDeleteTempDir(tempDir);
      }
    });
    final heicFile = await writeFtypImage(tempDir, 'pet.heic', 'heic');
    final heifFile = await writeFtypImage(tempDir, 'pet.heif', 'mif1');

    final detectedContentTypes = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        expect(options.method, 'POST');
        expect(options.path, '/api/pets/pet-1/photos');
        expect(options.data, isA<FormData>());

        final formData = options.data as FormData;
        detectedContentTypes.add(
          formData.files.single.value.contentType.toString(),
        );
        return jsonResponse(petPhotoJson());
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
      preferences: SharedPreferencesAsync(),
    );

    await repository.uploadPetPhoto(
      petId: 'pet-1',
      photo: XFile(heicFile.path, name: 'pet.heic'),
    );
    await repository.uploadPetPhoto(
      petId: 'pet-1',
      photo: XFile(heifFile.path, name: 'pet.heif'),
    );

    expect(detectedContentTypes, ['image/heic', 'image/heif']);
  });

  test('uploads pet photos from optimized temp payloads', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await _safeDeleteTempDir(tempDir);
      }
    });
    final source = await writeTinyJpeg(tempDir, 'source.jpg');
    final optimized = await writeTinyJpeg(tempDir, 'optimized.jpg');

    String? uploadedFileName;
    String? uploadedContentType;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        final formData = options.data as FormData;
        uploadedFileName = formData.files.single.value.filename;
        uploadedContentType = formData.files.single.value.contentType
            .toString();
        return jsonResponse(petPhotoJson());
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
      preferences: SharedPreferencesAsync(),
      imageUploadOptimizer: FakeImageUploadOptimizer(petPhoto: optimized),
    );

    await repository.uploadPetPhoto(
      petId: 'pet-1',
      photo: XFile(source.path, name: 'source.bin', mimeType: 'image/png'),
    );

    expect(uploadedFileName, 'optimized.jpg');
    expect(uploadedContentType, 'image/jpeg');
  });

  test(
    'rejects spoofed pet photo before optimizer can replace payload',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'petmagic-pet-photo-test-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await _safeDeleteTempDir(tempDir);
        }
      });
      final source = File('${tempDir.path}/source.jpg');
      await source.writeAsBytes('%PDF-1.7 not an image'.codeUnits, flush: true);
      final optimized = await writeTinyJpeg(tempDir, 'optimized.jpg');
      final optimizer = FakeImageUploadOptimizer(petPhoto: optimized);
      var didAttemptUpload = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = FakeHttpClientAdapter((options) async {
          didAttemptUpload = true;
          return jsonResponse(petPhotoJson());
        });
      final repository = TemplateGenerationRepository(
        dio: dio,
        sessionStorage: TestSessionStorage(sessionFixture()),
        preferences: SharedPreferencesAsync(),
        imageUploadOptimizer: optimizer,
      );

      await expectLater(
        repository.uploadPetPhoto(
          petId: 'pet-1',
          photo: XFile(source.path, name: 'source.jpg', mimeType: 'image/jpeg'),
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
      expect(optimizer.petPhotoOptimizeCalls, 0);
    },
  );

  test('keeps pet photo CRUD request contracts stable', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        requests.add(options);
        switch (options.path) {
          case '/api/pets/pet-1/photos':
            return jsonResponse([petPhotoJson()]);
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

  test('parses pet avatar fallback fields from list response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        expect(options.method, 'GET');
        expect(options.path, '/api/pets');
        return jsonResponse([
          {
            ...petJson(),
            'avatarThumbnailUrl': ' https://cdn.petmagic.app/bella-thumb.jpg ',
          },
          {
            ...petJson(id: 'pet-2'),
            'mainPhotoUrl': 'https://cdn.petmagic.app/milo-main.jpg',
          },
        ]);
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
      preferences: SharedPreferencesAsync(),
    );

    final pets = await repository.fetchPets();

    expect(pets.map((pet) => pet.avatarUrl), [
      'https://cdn.petmagic.app/bella-thumb.jpg',
      'https://cdn.petmagic.app/milo-main.jpg',
    ]);
  });

  test('encodes pet photo API path segments', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'petmagic-pet-photo-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await _safeDeleteTempDir(tempDir);
      }
    });
    final file = await writeTinyJpeg(tempDir, 'pet.jpg');
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
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        requests.add(options);
        final expectedPath = expectedPaths[requests.length - 1];
        expect(options.path, expectedPath);
        return switch (requests.length) {
          1 => jsonResponse(petJson(id: petId)),
          2 => ResponseBody.fromString('', 204),
          3 => jsonResponse(petPhotoJson()),
          4 => jsonResponse([petPhotoJson()]),
          5 => jsonResponse(petPhotoJson()),
          6 => jsonResponse(petPhotoJson()),
          7 => ResponseBody.fromString('', 204),
          8 => jsonResponse([
            generationJson(
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
      sessionStorage: TestSessionStorage(sessionFixture()),
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
      'GET /api/templates/generations/$encodedGenerationId',
      'GET /api/templates/generation-results/$encodedResultId/compatible-templates',
      'POST /api/templates/generations/$encodedSourceGenerationId/generate-similar',
      'GET /api/templates/generations/$encodedNextGenerationId',
      'POST /api/templates/generations/$encodedGenerationId/remove-watermark',
      'POST /api/templates/$encodedTemplateId/analytics/events',
      'POST /api/templates/$encodedTemplateId/analytics/events',
      'GET /api/templates/generations/$encodedGenerationId/download',
      'POST /api/templates/generations/$encodedGenerationId/share',
      'POST /api/templates/generations/$encodedGenerationId/mark-read',
      'DELETE /api/templates/generations/$encodedGenerationId',
    ];
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
      ..httpClientAdapter = FakeHttpClientAdapter((options) async {
        requests.add(options);
        expect(
          '${options.method} ${options.path}',
          expectedRequests[requests.length - 1],
        );
        return switch (requests.length) {
          1 => jsonResponse(
            generationJson(
              generationId: generationId,
              status: 'completed',
              updatedAtUtc: '2026-06-14T12:00:00Z',
            ),
          ),
          2 => jsonResponse({
            'resultId': resultId,
            'inputMediaType': 'image',
            'templates': [],
          }),
          3 => jsonResponse({'generationId': nextGenerationId}),
          4 => jsonResponse(
            generationJson(
              generationId: nextGenerationId,
              status: 'completed',
              updatedAtUtc: '2026-06-14T12:01:00Z',
            ),
          ),
          5 => jsonResponse({'watermarkRemoved': true, 'creditsSpent': 1}),
          6 || 7 || 10 || 11 => ResponseBody.fromString('', 204),
          8 => jsonResponse({
            'signedMediaUrl': 'https://cdn.petmagic.test/generated.jpg',
            'hasWatermark': false,
            'fileName': 'generated.jpg',
            'contentType': 'image/png',
          }),
          9 => jsonResponse({
            'shareUrl': 'https://app.petmagic.app/share/generation/token',
            'shareToken': 'token',
            'signedMediaUrl': 'https://cdn.petmagic.test/generated.jpg',
            'hasWatermark': false,
            'fileName': 'generated.jpg',
            'contentType': 'image/png',
          }),
          _ => fail('Unexpected request ${options.method} ${options.path}'),
        };
      });
    final repository = TemplateGenerationRepository(
      dio: dio,
      sessionStorage: TestSessionStorage(sessionFixture()),
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
    expect(share.mediaUrl, 'https://cdn.petmagic.test/generated.jpg');
    expect(share.shareUrl, 'https://app.petmagic.app/share/generation/token');
    expect(share.shareToken, 'token');
    expect(share.fileName, 'generated.jpg');
    expect(
      requests.map((request) => '${request.method} ${request.path}').toList(),
      expectedRequests,
    );
    expect(requests[5].data, containsPair('generationId', generationId));
    expect(requests[6].data, containsPair('generationId', generationId));
  });
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? initialValues])
    : values = initialValues ?? <String, String>{};

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
      return;
    }

    values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
