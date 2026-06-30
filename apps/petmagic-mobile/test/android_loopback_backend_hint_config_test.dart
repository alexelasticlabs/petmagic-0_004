import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

void main() {
  test('shows Android localhost hint only for debug Android loopback URLs', () {
    final config = AppConfig.androidLoopbackBackendHintConfig(
      configuredBaseUrl: 'http://127.0.0.1:5000',
      isDebugBuild: true,
      isWeb: false,
      isAndroidDevice: true,
    );

    expect(config, isNotNull);
    expect(config!.baseUrl, 'http://127.0.0.1:5000');
    expect(config.port, 5000);
  });

  test('does not show Android localhost hint for non-loopback or release', () {
    expect(
      AppConfig.androidLoopbackBackendHintConfig(
        configuredBaseUrl: 'http://192.168.1.10:5000',
        isDebugBuild: true,
        isWeb: false,
        isAndroidDevice: true,
      ),
      isNull,
    );

    expect(
      AppConfig.androidLoopbackBackendHintConfig(
        configuredBaseUrl: 'http://127.0.0.1:5000',
        isDebugBuild: false,
        isWeb: false,
        isAndroidDevice: true,
      ),
      isNull,
    );
  });
}
