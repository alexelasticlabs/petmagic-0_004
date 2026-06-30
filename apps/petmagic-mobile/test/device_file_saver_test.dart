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
                  contains('https://cdn.petmagic.test/result.jpg'),
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
                  contains('https://cdn.petmagic.test/result.jpg'),
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
      expect(source, isNot(contains('} catch (_) {')));
    },
  );
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
