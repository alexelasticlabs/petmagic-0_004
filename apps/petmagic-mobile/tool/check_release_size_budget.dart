import 'dart:io';

void main(List<String> arguments) {
  final options = _parseOptions(arguments);
  final artifactPath = options['artifact'];
  final baselineRaw = options['baseline-bytes'];
  final growthRaw = options['max-growth-percent'] ?? '5';
  if (artifactPath == null || baselineRaw == null) {
    stderr.writeln(
      'Usage: dart run tool/check_release_size_budget.dart '
      '--artifact <path> --baseline-bytes <bytes> '
      '[--max-growth-percent <percent>]',
    );
    exitCode = 64;
    return;
  }

  final baselineBytes = int.tryParse(baselineRaw);
  final maxGrowthPercent = double.tryParse(growthRaw);
  if (baselineBytes == null || baselineBytes <= 0 || maxGrowthPercent == null) {
    stderr.writeln('Release size budget arguments are invalid.');
    exitCode = 64;
    return;
  }

  final artifact = File(artifactPath);
  if (!artifact.existsSync()) {
    stderr.writeln('Release artifact does not exist: $artifactPath');
    exitCode = 66;
    return;
  }

  final sizeBytes = artifact.lengthSync();
  final maximumBytes = (baselineBytes * (1 + maxGrowthPercent / 100)).floor();
  final growthPercent = (sizeBytes - baselineBytes) / baselineBytes * 100;
  stdout.writeln(
    'release_size_bytes=$sizeBytes baseline_bytes=$baselineBytes '
    'growth_percent=${growthPercent.toStringAsFixed(2)} '
    'maximum_bytes=$maximumBytes',
  );
  if (sizeBytes > maximumBytes) {
    stderr.writeln(
      'Release artifact exceeds the allowed ${maxGrowthPercent.toStringAsFixed(1)}% size growth.',
    );
    exitCode = 1;
  }
}

Map<String, String> _parseOptions(List<String> arguments) {
  final options = <String, String>{};
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (!argument.startsWith('--') || index + 1 >= arguments.length) {
      continue;
    }
    options[argument.substring(2)] = arguments[++index];
  }
  return options;
}
