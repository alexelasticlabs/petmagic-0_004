import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: _writeIntegrationResponseData,
  writeResponseOnFailure: true,
);

Future<void> _writeIntegrationResponseData(Map<String, dynamic>? data) async {
  final directory = Directory(
    Platform.environment['FLUTTER_TEST_OUTPUTS_DIR'] ?? 'build',
  );
  await directory.create(recursive: true);
  final file = File('${directory.path}/integration_response_data.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  // ignore: avoid_print
  print('Wrote integration response data to ${file.path}');
}
