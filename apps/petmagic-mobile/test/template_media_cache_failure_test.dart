import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';

import 'template_media_performance_test_support.dart';

const _deadline = Duration(seconds: 6);

void main() {
  configureTemplateMediaPerformanceHarness(ensureWidgets: false);

  for (final isVideo in [false, true]) {
    final kind = isVideo ? 'preview' : 'thumbnail';
    final fetch = isVideo
        ? TemplateMediaCache.fetchPreviewFile
        : TemplateMediaCache.fetchThumbnailFile;
    final remove = isVideo
        ? TemplateMediaCache.removePreviewFile
        : TemplateMediaCache.removeThumbnailFile;
    final lookup = isVideo
        ? TemplateMediaCache.getCachedPreviewFile
        : TemplateMediaCache.getCachedThumbnailFile;

    test(
      '$kind removal isolates a fresh same-key fetch from an older download',
      () async {
        await TemplateMediaCache.clearAll().timeout(_deadline);
        final started = Completer<void>();
        final releaseOld = Completer<void>();
        var requests = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final subscription = server.listen((request) async {
          final current = ++requests;
          if (current == 1) {
            started.complete();
            await releaseOld.future;
          }
          final bytes = [current, 23, 45, 67];
          request.response.headers
            ..contentType = isVideo
                ? ContentType('video', 'mp4')
                : ContentType('image', 'jpeg')
            ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
          request.response.contentLength = bytes.length;
          request.response.add(bytes);
          await request.response.close();
        });
        addTearDown(() async {
          if (!releaseOld.isCompleted) releaseOld.complete();
          await subscription.cancel().timeout(_deadline);
          await server.close(force: true).timeout(_deadline);
          await TemplateMediaCache.clearAll().timeout(_deadline);
        });

        final url = 'http://${server.address.host}:${server.port}/$kind.media';
        final stale = _capture(fetch(url, mediaVersion: 7));
        await started.future.timeout(_deadline);
        await remove(url, mediaVersion: 7).timeout(_deadline);
        final fresh = _capture(fetch(url, mediaVersion: 7));
        // Let cache lookups run while the first HTTP response remains blocked.
        await Future<void>.delayed(Duration.zero);
        releaseOld.complete();

        expect(await stale, isA<StateError>());
        final freshResult = await fresh;
        expect(freshResult, isA<File>());
        final freshFile = freshResult as File;
        expect(await freshFile.exists(), isTrue);
        expect(await freshFile.readAsBytes(), [2, 23, 45, 67]);
        expect(requests, 2);
        expect((await lookup(url, mediaVersion: 7))?.path, freshFile.path);

        final reused = await fetch(url, mediaVersion: 7).timeout(_deadline);
        expect(await reused.readAsBytes(), [2, 23, 45, 67]);
        expect(requests, 2);
      },
      timeout: const Timeout(Duration(seconds: 25)),
    );

    test(
      '$kind clear removes orphan files from repeated broken chunked downloads',
      () async {
        await TemplateMediaCache.clearAll().timeout(_deadline);
        final cache = isVideo
            ? TemplateMediaCache.previewVideoCache
            : TemplateMediaCache.thumbnailCache;
        final probe = await cache.config.fileSystem.createFile('failure-probe');
        final directory = probe.parent;
        final sockets = <Socket>[];
        final arrivals = <Completer<Socket>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final subscription = server.listen((request) async {
          final index = int.parse(request.uri.pathSegments.last);
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          sockets.add(socket);
          final bytes = Uint8List(256 * 1024);
          socket.add(
            ascii.encode(
              'HTTP/1.1 200 OK\r\n'
              'Content-Type: ${isVideo ? 'video/mp4' : 'image/jpeg'}\r\n'
              'Transfer-Encoding: chunked\r\n'
              'Cache-Control: max-age=3600\r\n'
              '\r\n'
              '${bytes.length.toRadixString(16)}\r\n',
            ),
          );
          socket.add(bytes);
          socket.add(ascii.encode('\r\n'));
          await socket.flush();
          arrivals[index].complete(socket);
          // The test waits for a physical partial file, then closes this socket
          // without the terminating zero chunk to produce a real stream error.
        });
        addTearDown(() async {
          for (final socket in sockets) {
            socket.destroy();
          }
          await subscription.cancel().timeout(_deadline);
          await server.close(force: true).timeout(_deadline);
          await TemplateMediaCache.clearAll().timeout(_deadline);
        });

        for (var attempt = 0; attempt < 3; attempt++) {
          final before = (await _cacheFiles(
            directory,
          )).map((file) => file.path).toSet();
          arrivals.add(Completer<Socket>());
          final url =
              'http://${server.address.host}:${server.port}/partial/$attempt';
          final result = _capture(fetch(url));
          final socket = await arrivals[attempt].future.timeout(_deadline);
          await _waitForPartialFile(directory, before).timeout(_deadline);
          socket.destroy();
          final failure = await result;
          expect(failure, isA<Exception>());
          expect(failure, isNot(isA<TimeoutException>()));
          expect(await lookup(url), isNull);
        }

        await TemplateMediaCache.clearAll().timeout(_deadline);
        expect(
          await _cacheFiles(directory),
          isEmpty,
          reason: 'Failed streams have no metadata but still consume disk.',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  }
}

Future<Object> _capture(Future<File> fetch) => fetch
    .timeout(_deadline)
    .then<Object>(
      (file) => file,
      onError: (Object error, StackTrace _) => error,
    );

Future<List<File>> _cacheFiles(Directory directory) async {
  if (!await directory.exists()) return [];
  return directory
      .list(followLinks: false)
      .where((entry) => entry is File)
      .cast<File>()
      .toList();
}

Future<void> _waitForPartialFile(
  Directory directory,
  Set<String> previous,
) async {
  final deadline = DateTime.now().add(_deadline);
  while (DateTime.now().isBefore(deadline)) {
    for (final file in await _cacheFiles(directory)) {
      if (!previous.contains(file.path) && await file.length() > 0) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException('The server did not produce a partial cache file.');
}
