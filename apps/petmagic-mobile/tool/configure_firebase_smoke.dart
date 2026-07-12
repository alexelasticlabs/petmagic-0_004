import 'dart:io';

void main(List<String> args) {
  final environment = _readEnvironment(args);
  final packageName = switch (environment) {
    'staging' => 'com.petmagic.app.staging',
    'production' => 'com.petmagic.app',
    _ => throw ArgumentError.value(environment, 'environment'),
  };

  _copyTemplate(
    sourcePath: 'android/app/google-services.json.example',
    targetPath: 'android/app/google-services.json',
    packageName: packageName,
  );
  _copyTemplate(
    sourcePath: 'android/app/google-services.json.example',
    targetPath: 'android/app/src/$environment/google-services.json',
    packageName: packageName,
  );
  _copyTemplate(
    sourcePath: 'ios/Runner/GoogleService-Info.plist.example',
    targetPath: 'ios/Runner/GoogleService-Info.plist',
    packageName: packageName,
  );

  stdout.writeln(
    'Generated placeholder Firebase configs for $environment packaging smoke. '
    'They are gitignored and must never be used for provider E2E or store rollout.',
  );
}

String _readEnvironment(List<String> args) {
  const prefix = '--environment=';
  final value = args
      .where((arg) => arg.startsWith(prefix))
      .map((arg) => arg.substring(prefix.length).trim().toLowerCase())
      .firstOrNull;
  if (value != 'staging' && value != 'production') {
    stderr.writeln(
      'Usage: dart run tool/configure_firebase_smoke.dart '
      '--environment=staging|production',
    );
    exitCode = 64;
    exit(64);
  }
  return value!;
}

void _copyTemplate({
  required String sourcePath,
  required String targetPath,
  required String packageName,
}) {
  final source = File(sourcePath);
  if (!source.existsSync()) {
    throw StateError('Missing Firebase smoke template: $sourcePath');
  }
  final target = File(targetPath);
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(
    source.readAsStringSync().replaceAll('APP_PACKAGE_NAME', packageName),
  );
}
