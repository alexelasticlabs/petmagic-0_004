import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'petmagic-image-optimizer-test-',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('compresses decodable generation images into temporary JPEGs', () async {
    final sourcePath = '${tempDir.path}/source-photo.jpg';
    final sourceBytes = _noisyJpegBytes(width: 1200, height: 900);
    await File(sourcePath).writeAsBytes(sourceBytes, flush: true);

    final optimizer = ImageUploadOptimizer(
      minInputBytes: 1,
      maxDimension: 420,
      jpegQuality: 60,
    );
    final optimized = await optimizer.optimizeGenerationSource(
      XFile(sourcePath, name: r'C:\Users\pet\source-photo.png'),
    );

    expect(optimized.isTemporary, true);
    expect(optimized.file.path, isNot(sourcePath));
    expect(optimized.file.name, endsWith('.jpg'));
    expect(optimized.file.name, isNot(contains(r'\')));
    expect(optimized.file.name, isNot(contains('/')));
    expect(optimized.file.mimeType, 'image/jpeg');

    final optimizedFile = File(optimized.file.path);
    expect(await optimizedFile.exists(), true);
    expect(await optimizedFile.length(), lessThan(sourceBytes.length));

    await optimized.dispose();
    expect(await optimizedFile.exists(), false);
    expect(await File(sourcePath).exists(), true);
  });

  test('keeps original file when the image cannot be decoded', () async {
    final sourcePath = '${tempDir.path}/source-photo.heic';
    await File(sourcePath).writeAsBytes(List<int>.filled(32, 7), flush: true);

    final optimizer = ImageUploadOptimizer(
      minInputBytes: 1,
      maxDimension: 420,
      jpegQuality: 60,
    );
    final optimized = await optimizer.optimizeGenerationSource(
      XFile(sourcePath, name: 'source-photo.heic', mimeType: 'image/heic'),
    );

    expect(optimized.isTemporary, false);
    expect(optimized.file.path, sourcePath);

    await optimized.dispose();
    expect(await File(sourcePath).exists(), true);
  });
}

Uint8List _noisyJpegBytes({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 31 + y * 17) & 0xff,
        (x * 13 + y * 29) & 0xff,
        (x * 7 + y * 19) & 0xff,
      );
    }
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}
