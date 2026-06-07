import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
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
