import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

void main() {
  test('media cache defaults stay production-safe', () {
    expect(AppConfig.mediaCacheMaxBytesSafe, 64 * 1024 * 1024);
    expect(AppConfig.previewVideoCacheMaxBytesSafe, 192 * 1024 * 1024);
    expect(AppConfig.mediaCacheStalePeriod, const Duration(hours: 24));
    expect(AppConfig.mediaTempFileTtl, const Duration(hours: 24));
    expect(AppConfig.decodedImageCacheMaxObjectsSafe, 200);
    expect(AppConfig.decodedImageCacheMaxBytesSafe, 48 * 1024 * 1024);
  });
}
