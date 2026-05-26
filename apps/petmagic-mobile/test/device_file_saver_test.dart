import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';

void main() {
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
}
