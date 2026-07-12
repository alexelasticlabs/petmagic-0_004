import 'dart:io';

void main(List<String> args) {
  final tag =
      _argument(args, '--tag=') ?? Platform.environment['GITHUB_REF_NAME'];
  if (tag == null || tag.isEmpty) {
    stderr.writeln('A release tag is required.');
    exitCode = 64;
    return;
  }

  final pubspec = File('pubspec.yaml').readAsStringSync();
  final version = RegExp(
    r'^version:\s*([^\s]+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec)?.group(1);
  if (version == null) {
    stderr.writeln('pubspec.yaml version is missing.');
    exitCode = 1;
    return;
  }

  final expectedTag = 'mobile-v$version';
  if (tag != expectedTag) {
    stderr.writeln('Release tag $tag must exactly match $expectedTag.');
    exitCode = 1;
    return;
  }
  stdout.writeln('Release version verified: $version');
}

String? _argument(List<String> args, String prefix) {
  for (final value in args) {
    if (value.startsWith(prefix)) return value.substring(prefix.length);
  }
  return null;
}
