import 'dart:convert';
import 'dart:io';

import 'l10n_same_value_allowlist.dart';

void main() {
  final root = Directory.current;
  final l10nDir = Directory('${root.path}/lib/l10n');
  final enFile = File('${l10nDir.path}/app_en.arb');

  if (!enFile.existsSync()) {
    stderr.writeln('Missing template locale file: ${enFile.path}');
    exitCode = 1;
    return;
  }

  final enMap = _readArb(enFile);
  final generationStatusKeys =
      enMap.keys
          .where((key) => key.startsWith('generationStatus'))
          .where((key) => !key.startsWith('@'))
          .toList(growable: false)
        ..sort();

  const additionalKeys = <String>[
    'templateFlowTemplateLabel',
    'templateFlowCostLabel',
    'templateFlowStepProcessPhoto',
    'templateFlowStepCreateMagic',
    'templateFlowStepFinalTouches',
    'templateFlowResultUnavailable',
    'templateFlowResultLoadFailed',
    'shellActiveGenerationLabel',
    'shellActiveGenerationFallback',
  ];

  if (generationStatusKeys.isEmpty) {
    stderr.writeln('No generationStatus keys found in app_en.arb');
    exitCode = 1;
    return;
  }

  final missingInEn = additionalKeys
      .where((key) => !enMap.containsKey(key))
      .toList(growable: false);
  if (missingInEn.isNotEmpty) {
    stderr.writeln(
      'Template locale is missing required keys: ${missingInEn.join(', ')}',
    );
    exitCode = 1;
    return;
  }

  final requiredKeys = <String>{
    ...generationStatusKeys,
    ...additionalKeys,
  }.toList(growable: false)..sort();

  const localeFiles = <String>[
    'app_ru.arb',
    'app_de.arb',
    'app_es.arb',
    'app_fr.arb',
    'app_it.arb',
    'app_pl.arb',
  ];

  const strictLocales = <String>{'ru', 'de', 'es', 'fr', 'it', 'pl'};

  var hasMissing = false;

  for (final localeFileName in localeFiles) {
    final localeFile = File('${l10nDir.path}/$localeFileName');
    if (!localeFile.existsSync()) {
      stderr.writeln('Missing locale file: ${localeFile.path}');
      hasMissing = true;
      continue;
    }

    final localeMap = _readArb(localeFile);
    final localeCode = _localeCodeFromFile(localeFileName);

    final missing = requiredKeys
        .where((key) => !localeMap.containsKey(key))
        .toList(growable: false);

    if (missing.isNotEmpty) {
      hasMissing = true;
      stderr.writeln(
        '$localeFileName is missing required localization keys: ${missing.join(', ')}',
      );
    }

    final emptyValues = requiredKeys
        .where((key) => localeMap.containsKey(key))
        .where((key) {
          final rawValue = localeMap[key];
          final value = rawValue is String ? rawValue.trim() : '';
          return value.isEmpty;
        })
        .toList(growable: false);

    if (emptyValues.isNotEmpty) {
      hasMissing = true;
      stderr.writeln(
        '$localeFileName has empty values for required keys: ${emptyValues.join(', ')}',
      );
    }

    if (strictLocales.contains(localeCode)) {
      final englishFallbackValues = requiredKeys
          .where((key) => localeMap.containsKey(key) && enMap.containsKey(key))
          .where((key) {
            final localValue = localeMap[key];
            final enValue = enMap[key];
            if (localValue is! String || enValue is! String) {
              return false;
            }
            if (isSameValueAllowed(localeCode, key)) {
              return false;
            }
            return localValue.trim() == enValue.trim();
          })
          .toList(growable: false);

      if (englishFallbackValues.isNotEmpty) {
        hasMissing = true;
        stderr.writeln(
          '$localeFileName has English fallback values for required keys: ${englishFallbackValues.join(', ')}',
        );
      }
    }
  }

  if (hasMissing) {
    stderr.writeln('Generation localization completeness check failed.');
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Generation localization completeness check passed (${requiredKeys.length} keys).',
  );
}

String _localeCodeFromFile(String fileName) {
  final nameWithoutExtension = fileName.replaceAll('.arb', '');
  final parts = nameWithoutExtension.split('_');
  return parts.isEmpty ? '' : parts.last.toLowerCase();
}

Map<String, dynamic> _readArb(File file) {
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw);

  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Invalid ARB JSON object in ${file.path}');
  }

  return decoded;
}
