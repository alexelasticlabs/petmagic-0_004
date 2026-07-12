import 'dart:convert';
import 'dart:io';

import 'l10n_same_value_allowlist.dart';

void main(List<String> args) {
  final root = Directory.current;
  final l10nDir = Directory('${root.path}/lib/l10n');
  final enFile = File('${l10nDir.path}/app_en.arb');

  if (!enFile.existsSync()) {
    stderr.writeln('Missing template locale file: ${enFile.path}');
    exitCode = 1;
    return;
  }

  final enMap = _readArb(enFile);
  final baseKeys = enMap.keys.where((key) => !key.startsWith('@')).toList()
    ..sort();

  const localeFiles = <String>[
    'app_ru.arb',
    'app_de.arb',
    'app_es.arb',
    'app_fr.arb',
    'app_it.arb',
    'app_pl.arb',
  ];

  var hasFailures = false;

  for (final localeFileName in localeFiles) {
    final file = File('${l10nDir.path}/$localeFileName');
    if (!file.existsSync()) {
      stderr.writeln('Missing locale file: ${file.path}');
      hasFailures = true;
      continue;
    }

    final localeMap = _readArb(file);
    final localeCode = _localeCodeFromFile(localeFileName);
    final missingKeys = baseKeys
        .where((key) => !localeMap.containsKey(key))
        .toList(growable: false);
    final emptyKeys = baseKeys
        .where((key) => localeMap.containsKey(key))
        .where((key) {
          final value = localeMap[key];
          return value is String && value.trim().isEmpty;
        })
        .toList(growable: false);
    final sameValueKeys = baseKeys
        .where((key) => localeMap.containsKey(key) && enMap.containsKey(key))
        .where((key) {
          if (isSameValueAllowed(localeCode, key)) {
            return false;
          }

          final localValue = localeMap[key];
          final enValue = enMap[key];
          return localValue is String &&
              enValue is String &&
              localValue.trim() == enValue.trim();
        })
        .toList(growable: false);

    if (missingKeys.isNotEmpty ||
        emptyKeys.isNotEmpty ||
        sameValueKeys.isNotEmpty) {
      hasFailures = true;
      stdout.writeln('[$localeFileName]');

      if (missingKeys.isNotEmpty) {
        stdout.writeln('  missing: ${missingKeys.join(', ')}');
      }
      if (emptyKeys.isNotEmpty) {
        stdout.writeln('  empty: ${emptyKeys.join(', ')}');
      }
      if (sameValueKeys.isNotEmpty) {
        stdout.writeln('  english fallback: ${sameValueKeys.join(', ')}');
      }
    }
  }

  if (hasFailures) {
    stderr.writeln('Localization completeness check failed.');
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Localization completeness check passed (${baseKeys.length} keys).',
  );
}

String _localeCodeFromFile(String fileName) {
  return fileName.replaceAll('.arb', '').split('_').last.toLowerCase();
}

Map<String, dynamic> _readArb(File file) {
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw);

  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Invalid ARB JSON object in ${file.path}');
  }

  return decoded;
}
