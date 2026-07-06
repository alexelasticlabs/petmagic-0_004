import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';

void main() {
  group('downloadFileBytes', () {
    test('streams bytes without retaining URL in errors', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          expect(options.responseType, ResponseType.stream);
          return ResponseBody.fromBytes([1, 2, 3], 200);
        });

      final bytes = await downloadFileBytes(
        'https://cdn.petmagic.test/result.jpg?signature=secret',
        client: dio,
        maxBytes: 8,
      );

      expect(bytes, [1, 2, 3]);
    });

    test(
      'rejects unsafe URL schemes and credentials before network request',
      () async {
        var requestCount = 0;
        final dio = Dio()
          ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
            requestCount++;
            return ResponseBody.fromBytes([1, 2, 3], 200);
          });

        for (final url in [
          'javascript:alert(1)',
          'file:///tmp/petmagic.jpg',
          '/relative/result.jpg',
          'http://evil.example/result.jpg',
          'https://user:secret@cdn.petmagic.test/result.jpg',
          'https://localhost/result.jpg',
          'https://127.0.0.1/result.jpg',
          'https://0.0.0.0/result.jpg',
          'https://10.0.0.5/result.jpg',
          'https://100.64.0.1/result.jpg',
          'https://169.254.169.254/latest/meta-data',
          'https://192.168.1.25/result.jpg',
          'https://[::1]/result.jpg',
          'https://[::]/result.jpg',
          'https://[fd00::1]/result.jpg',
          'https://[fe80::1]/result.jpg',
          'https://[::ffff:127.0.0.1]/result.jpg',
          'https://[::ffff:10.0.0.5]/result.jpg',
        ]) {
          await expectLater(
            downloadFileBytes(url, client: dio, maxBytes: 8),
            throwsA(
              isA<FormatException>().having(
                (error) => error.message,
                'message',
                'unsafe_download_url',
              ),
            ),
          );
        }

        expect(requestCount, 0);
      },
    );

    test(
      'allows local debug http downloads without allowing external http',
      () async {
        final requestedUrls = <String>[];
        final dio = Dio()
          ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
            requestedUrls.add(options.uri.toString());
            return ResponseBody.fromBytes([1, 2, 3], 200);
          });

        final bytes = await downloadFileBytes(
          'http://127.0.0.1:5000/result.jpg?signature=secret',
          client: dio,
          maxBytes: 8,
        );

        expect(bytes, [1, 2, 3]);
        expect(requestedUrls, [
          'http://127.0.0.1:5000/result.jpg?signature=secret',
        ]);
      },
    );

    test('rejects responses larger than content length limit', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          return ResponseBody.fromBytes(
            [1, 2],
            200,
            headers: {
              Headers.contentLengthHeader: ['12'],
            },
          );
        });

      await expectLater(
        downloadFileBytes(
          'https://cdn.petmagic.test/result.jpg?signature=secret',
          client: dio,
          maxBytes: 8,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            isNot(contains('signature=secret')),
          ),
        ),
      );
    });

    test('sanitizes failed download exceptions', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          return ResponseBody.fromString('provider failure', 503);
        });

      await expectLater(
        downloadFileBytes(
          'https://cdn.petmagic.test/result.jpg?signature=secret&token=raw',
          client: dio,
          maxBytes: 8,
        ),
        throwsA(
          isA<DioException>()
              .having(
                (error) => error.requestOptions.path,
                'request path',
                allOf(
                  equals('https://cdn.petmagic.test'),
                  isNot(contains('result.jpg')),
                  isNot(contains('signature=secret')),
                  isNot(contains('token=raw')),
                ),
              )
              .having(
                (error) => error.message,
                'message',
                allOf(
                  isNot(contains('signature=secret')),
                  isNot(contains('token=raw')),
                ),
              )
              .having(
                (error) => error.response?.requestOptions.path,
                'response request path',
                allOf(
                  equals('https://cdn.petmagic.test'),
                  isNot(contains('result.jpg')),
                  isNot(contains('signature=secret')),
                  isNot(contains('token=raw')),
                ),
              ),
        ),
      );
    });

    test('stops reading when streamed bytes exceed limit', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          return ResponseBody(
            Stream<Uint8List>.fromIterable([
              Uint8List.fromList([1, 2, 3, 4]),
              Uint8List.fromList([5, 6, 7, 8, 9]),
            ]),
            200,
          );
        });

      await expectLater(
        downloadFileBytes(
          'https://cdn.petmagic.test/result.jpg?signature=secret',
          client: dio,
          maxBytes: 8,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('stops streamed download promptly when cancelled', () async {
      final stream = StreamController<Uint8List>();
      final cancelToken = CancelToken();
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          return ResponseBody(stream.stream, 200);
        });

      final downloadFuture = downloadFileBytes(
        'https://cdn.petmagic.test/result.jpg?signature=secret',
        client: dio,
        cancelToken: cancelToken,
        maxBytes: 32,
      );
      final expectation = expectLater(
        downloadFuture,
        throwsA(
          isA<DioException>()
              .having((error) => error.type, 'type', DioExceptionType.cancel)
              .having(
                (error) => error.requestOptions.path,
                'path',
                isNot(contains('signature=secret')),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('signature=secret')),
              ),
        ),
      );

      stream.add(Uint8List.fromList([1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      cancelToken.cancel('user_left_screen');
      stream.add(Uint8List.fromList([4, 5, 6]));
      unawaited(stream.close());

      await expectation;
    });
  });

  group('cacheRemoteMediaFile', () {
    test('writes supported media payloads to a temp file', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          return ResponseBody.fromBytes(const [0xFF, 0xD8, 0xFF, 0xD9], 200);
        });

      final file = await cacheRemoteMediaFile(
        mediaUrl: 'https://cdn.petmagic.test/result.jpg?signature=secret',
        fileName: 'remote-valid.jpg',
        client: dio,
      );
      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), const [0xFF, 0xD8, 0xFF, 0xD9]);
    });

    test('uses unique temp files for repeated remote cache names', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          return ResponseBody.fromBytes(const [0xFF, 0xD8, 0xFF, 0xD9], 200);
        });

      final first = await cacheRemoteMediaFile(
        mediaUrl: 'https://cdn.petmagic.test/result.jpg?signature=secret',
        fileName: 'shared-name.jpg',
        client: dio,
      );
      final second = await cacheRemoteMediaFile(
        mediaUrl: 'https://cdn.petmagic.test/result.jpg?signature=secret',
        fileName: 'shared-name.jpg',
        client: dio,
      );
      addTearDown(() async {
        if (await first.exists()) {
          await first.delete();
        }
        if (await second.exists()) {
          await second.delete();
        }
      });

      expect(first.path, isNot(second.path));
      expect(await first.exists(), isTrue);
      expect(await second.exists(), isTrue);
      expect(await first.readAsBytes(), const [0xFF, 0xD8, 0xFF, 0xD9]);
      expect(await second.readAsBytes(), const [0xFF, 0xD8, 0xFF, 0xD9]);
    });

    test('accepts supported mp4 container brands', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          return ResponseBody.fromBytes(const [
            0x00,
            0x00,
            0x00,
            0x18,
            0x66,
            0x74,
            0x79,
            0x70,
            0x6D,
            0x70,
            0x34,
            0x32,
            0x00,
            0x00,
            0x00,
            0x00,
          ], 200);
        });

      final file = await cacheRemoteMediaFile(
        mediaUrl: 'https://cdn.petmagic.test/result.mp4?signature=secret',
        fileName: 'remote-valid.mp4',
        client: dio,
      );
      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      expect(await file.exists(), isTrue);
    });

    test(
      'rejects unsupported remote payloads before writing temp files',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
            return ResponseBody.fromBytes('not-media'.codeUnits, 200);
          });
        final target = File(
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'petmagic_remote-invalid.jpg',
        );
        addTearDown(() async {
          if (await target.exists()) {
            await target.delete();
          }
        });

        await expectLater(
          cacheRemoteMediaFile(
            mediaUrl: 'https://cdn.petmagic.test/result.jpg?signature=secret',
            fileName: 'remote-invalid.jpg',
            client: dio,
          ),
          throwsA(isA<StateError>()),
        );
        expect(target.existsSync(), isFalse);
      },
    );

    test(
      'rejects unsupported iso bmff brands before writing temp files',
      () async {
        final dio = Dio()
          ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
            return ResponseBody.fromBytes(const [
              0x00,
              0x00,
              0x00,
              0x18,
              0x66,
              0x74,
              0x79,
              0x70,
              0x68,
              0x65,
              0x69,
              0x63,
              0x00,
              0x00,
              0x00,
              0x00,
            ], 200);
          });

        await expectLater(
          cacheRemoteMediaFile(
            mediaUrl: 'https://cdn.petmagic.test/result.bin?signature=secret',
            fileName: 'remote-invalid.bin',
            client: dio,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('sanitizeFileName', () {
    test('returns fallback for null or empty', () {
      expect(sanitizeFileName(null, fallback: 'fallback.jpg'), 'fallback.jpg');
      expect(sanitizeFileName('   ', fallback: 'fallback.jpg'), 'fallback.jpg');
    });

    test('normalizes spaces and disallowed chars', () {
      expect(
        sanitizeFileName(' my *pet* photo?.jpg ', fallback: 'fallback.jpg'),
        'my_pet_photo_.jpg',
      );
    });

    test('normalizes platform path fragments when caller passes basename', () {
      expect(
        sanitizeFileName('pet photo (final).jpg', fallback: 'fallback.jpg'),
        'pet_photo_final_.jpg',
      );
    });
  });

  group('extensionFromUrl', () {
    test('extracts extension from url with query', () {
      expect(
        extensionFromUrl('https://cdn.petmagic.ai/result/file.MP4?token=123'),
        'mp4',
      );
    });

    test('returns empty when extension missing', () {
      expect(extensionFromUrl('https://cdn.petmagic.ai/result/file'), '');
    });
  });

  group('extractFileExtension', () {
    test('extracts extension from file name', () {
      expect(extractFileExtension('petmagic_result_1.jpg'), 'jpg');
      expect(extractFileExtension('petmagic_result_1.MP4'), 'mp4');
    });

    test('returns null when extension missing', () {
      expect(extractFileExtension('petmagic_result_1'), isNull);
      expect(extractFileExtension('.hiddenfile'), isNull);
    });
  });

  test(
    'media share and save utilities log failures without exposing raw paths or URLs',
    () async {
      final source = await File(
        'lib/shared/files/media_share_save.dart',
      ).readAsString();

      expect(source, contains('AppLogger.warn('));
      expect(source, contains("feature: 'Shared.MediaShareSave'"));
      expect(source, contains("operation: 'save_remote_to_gallery'"));
      expect(source, contains("operation: 'save_local_to_gallery'"));
      expect(source, contains("operation: 'validate_local_media_path'"));
      expect(source, isNot(contains('} catch (_) {\n    return')));
    },
  );

  test(
    'local media cancellation exceptions do not include raw file paths',
    () async {
      final source = await File(
        'lib/shared/files/media_share_save.dart',
      ).readAsString();
      final method = _extractMethodBody(source, 'void _throwIfCancelled(');

      expect(method, contains("RequestOptions(path: '/local-media-action')"));
      expect(method, isNot(contains('RequestOptions(path: path)')));
      expect(method, isNot(contains('RequestOptions(path: filePath)')));
    },
  );

  test(
    'shareRemoteMediaFile always deletes temp cache after share completes',
    () async {
      final source = await File(
        'lib/shared/files/media_share_save.dart',
      ).readAsString();
      final method = _extractMethodBody(
        source,
        'Future<void> shareRemoteMediaFile({',
      );

      expect(method, contains('try {'));
      expect(method, contains('await SharePlus.instance.share('));
      expect(method, contains('finally {'));
      expect(
        method,
        contains('await TempMediaCleanup.deleteIfExists(tempFile);'),
      );
      expect(method, isNot(contains('TempMediaCleanup.scheduleTtlSweep();')));
    },
  );

  test('saveBytesToDevice uses resilient temp cleanup in finally', () async {
    final source = await File(
      'lib/shared/files/device_file_saver.dart',
    ).readAsString();
    final method = _extractMethodBody(
      source,
      'Future<bool> saveBytesToDevice({',
    );

    expect(method, contains('try {'));
    expect(
      method,
      contains('await tempFile.writeAsBytes(bytes, flush: true);'),
    );
    expect(method, contains('finally {'));
    expect(
      method,
      contains('await TempMediaCleanup.deleteIfExists(tempFile);'),
    );
    expect(
      method,
      isNot(
        contains(
          'if (await tempFile.exists()) {\n      await tempFile.delete();\n    }',
        ),
      ),
    );
    expect(
      method,
      contains('TempMediaCleanup.createScopedTempFile(safeFileName)'),
    );
  });

  test(
    'cacheRemoteMediaFile deletes partial temp files when disk write fails',
    () async {
      final source = await File(
        'lib/shared/files/media_share_save.dart',
      ).readAsString();
      final method = _extractMethodBody(
        source,
        'Future<File> cacheRemoteMediaFile({',
      );

      expect(method, contains('try {'));
      expect(
        method,
        contains('await tempFile.writeAsBytes(bytes, flush: true);'),
      );
      expect(method, contains('} catch (error, stackTrace) {'));
      expect(method, contains("feature: 'Files.MediaShare'"));
      expect(method, contains("operation: 'cache_remote_media_file'"));
      expect(method, contains('error: error'));
      expect(method, contains('stackTrace: stackTrace'));
      expect(
        method,
        contains('await TempMediaCleanup.deleteIfExists(tempFile);'),
      );
      expect(method, contains('rethrow;'));
    },
  );

  test('shareRemoteMediaFile uses a sanitized share filename', () async {
    final source = await File(
      'lib/shared/files/media_share_save.dart',
    ).readAsString();
    final method = _extractMethodBody(
      source,
      'Future<void> shareRemoteMediaFile({',
    );

    expect(
      method,
      contains('XFile(tempFile.path, name: _safeMediaFileName(fileName))'),
    );
    expect(method, isNot(contains('files: [XFile(tempFile.path)]')));
  });

  test(
    'saveRemoteMediaToGallery deletes temp cache after success or failure',
    () async {
      final source = await File(
        'lib/shared/files/media_share_save.dart',
      ).readAsString();
      final method = _extractMethodBody(
        source,
        'Future<bool> saveRemoteMediaToGallery({',
      );

      expect(method, contains('try {'));
      expect(method, contains('catch (error, stackTrace)'));
      expect(method, contains('finally {'));
      expect(
        method,
        contains('await TempMediaCleanup.deleteIfExists(tempFile);'),
      );
      expect(method, isNot(contains('TempMediaCleanup.scheduleTtlSweep();')));
    },
  );
}

String _extractMethodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative);

  final bodyStart = source.indexOf('{', start + signature.length);
  expect(bodyStart, isNonNegative);

  var depth = 0;
  for (var index = bodyStart; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(bodyStart, index + 1);
      }
    }
  }

  fail('Could not extract method body for $signature');
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
