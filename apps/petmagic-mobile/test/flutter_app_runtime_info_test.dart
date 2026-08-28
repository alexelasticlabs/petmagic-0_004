import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/platform/flutter_app_runtime_info.dart';

void main() {
  test('uses the selected app locale when one is available', () {
    const runtimeInfo = FlutterAppRuntimeInfo(
      localeOverride: Locale('pl', 'PL'),
    );

    expect(runtimeInfo.locale.languageTag, 'pl-PL');
    expect(runtimeInfo.locale.countryCode, 'PL');
  });
}
