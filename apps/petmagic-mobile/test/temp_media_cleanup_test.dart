import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/shared/files/temp_media_cleanup.dart';

void main() {
  test('sweepExpiredFiles removes only old prefixed temp files', () async {
    final sandbox = await Directory.systemTemp.createTemp('petmagic_cleanup_');
    addTearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    final oldPrefixed = File(
      '${sandbox.path}${Platform.pathSeparator}petmagic_old.txt',
    )..writeAsStringSync('old');
    final freshPrefixed = File(
      '${sandbox.path}${Platform.pathSeparator}petmagic_fresh.txt',
    )..writeAsStringSync('fresh');
    final oldForeign = File(
      '${sandbox.path}${Platform.pathSeparator}foreign_old.txt',
    )..writeAsStringSync('foreign');

    final now = DateTime.now();
    final staleTime = now.subtract(const Duration(hours: 30));
    oldPrefixed.setLastModifiedSync(staleTime);
    oldForeign.setLastModifiedSync(staleTime);

    await TempMediaCleanup.sweepExpiredFiles(
      tempDirectory: sandbox,
      ttl: const Duration(hours: 24),
      now: now,
    );

    expect(await oldPrefixed.exists(), isFalse);
    expect(await freshPrefixed.exists(), isTrue);
    expect(await oldForeign.exists(), isTrue);
  });
}
