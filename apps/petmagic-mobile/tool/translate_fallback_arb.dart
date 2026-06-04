import 'dart:async';
import 'dart:convert';
import 'dart:io';

const List<(String fileName, String locale)> targets = [
  ('app_de.arb', 'de'),
  ('app_es.arb', 'es'),
  ('app_fr.arb', 'fr'),
  ('app_it.arb', 'it'),
  ('app_pl.arb', 'pl'),
];

final RegExp placeholderPattern = RegExp(r'\{[^{}]+\}');
const String newlineToken = '___PM_NL___';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final l10nDir = Directory('lib/l10n');
  final enPath = File('${l10nDir.path}/app_en.arb');

  if (!enPath.existsSync()) {
    stderr.writeln('Missing template locale file: ${enPath.path}');
    exitCode = 1;
    return;
  }

  final Map<String, dynamic> enData = _readArb(enPath);
  final failures = <String>[];

  final activeTargets = options.locale == null
      ? targets
      : targets.where((target) => target.$2 == options.locale).toList();

  if (options.locale != null && activeTargets.isEmpty) {
    throw ArgumentError('Unknown locale: ${options.locale}');
  }

  for (final target in activeTargets) {
    final fileName = target.$1;
    final locale = target.$2;
    final path = File('${l10nDir.path}/$fileName');

    if (!path.existsSync()) {
      stderr.writeln('Missing locale file: ${path.path}');
      exitCode = 1;
      continue;
    }

    final Map<String, dynamic> localeData = _readArb(path);
    var translatedCount = 0;

    final toTranslate = <_TranslationJob>[];

    for (final entry in enData.entries) {
      final key = entry.key;
      final enValue = entry.value;

      if (key.startsWith('@')) {
        continue;
      }
      if (!localeData.containsKey(key)) {
        continue;
      }

      final localValue = localeData[key];
      if (enValue is! String || localValue is! String) {
        continue;
      }
      if (localValue != enValue) {
        continue;
      }

      final protected = _protectText(enValue);
      toTranslate.add(_TranslationJob(key, protected.text, protected.tokens));
    }

    if (options.max > 0 && toTranslate.length > options.max) {
      toTranslate.removeRange(options.max, toTranslate.length);
    }

    stdout.writeln('$fileName: queued=${toTranslate.length}');

    for (var index = 0; index < toTranslate.length; index += 40) {
      final chunk = toTranslate.sublist(
        index,
        index + 40 > toTranslate.length ? toTranslate.length : index + 40,
      );
      final chunkNumber = index ~/ 40 + 1;
      stdout.writeln(
        '$fileName: chunk $chunkNumber (${index + 1}-${index + chunk.length})',
      );

      try {
        final translatedValues = await _translateBatchWithRetry(
          locale,
          chunk.map((item) => item.text).toList(),
        );

        for (var i = 0; i < chunk.length; i++) {
          final translated = translatedValues[i];
          if (translated == null) {
            failures.add('$fileName:${chunk[i].key}:empty_translation');
            continue;
          }

          localeData[chunk[i].key] = _restoreText(translated, chunk[i].tokens);
          translatedCount++;
        }
      } catch (error) {
        for (final item in chunk) {
          failures.add('$fileName:${item.key}:$error');
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    path.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(localeData)}\n',
      encoding: utf8,
    );
    stdout.writeln('$fileName: translated=$translatedCount');
  }

  stdout.writeln('---TRANSLATION_FAILURES---');
  if (failures.isEmpty) {
    stdout.writeln('none');
  } else {
    for (final failure in failures) {
      stdout.writeln(failure);
    }
  }
}

class _Options {
  const _Options({required this.locale, required this.max});

  final String? locale;
  final int max;
}

class _TranslationJob {
  const _TranslationJob(this.key, this.text, this.tokens);

  final String key;
  final String text;
  final Map<String, String> tokens;
}

class _ProtectedText {
  const _ProtectedText(this.text, this.tokens);

  final String text;
  final Map<String, String> tokens;
}

_Options _parseArgs(List<String> args) {
  String? locale;
  var max = 0;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--locale':
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for --locale');
        }
        locale = args[++i];
        break;
      case '--max':
        if (i + 1 >= args.length) {
          throw ArgumentError('Missing value for --max');
        }
        max = int.parse(args[++i]);
        break;
      default:
        throw ArgumentError('Unknown argument: $arg');
    }
  }

  return _Options(locale: locale, max: max);
}

Map<String, dynamic> _readArb(File file) {
  final decoded = jsonDecode(file.readAsStringSync());

  if (decoded is! Map<String, dynamic>) {
    throw FormatException('Invalid ARB JSON object in ${file.path}');
  }

  return decoded;
}

_ProtectedText _protectText(String text) {
  final tokens = <String, String>{};
  var index = 0;
  var protected = text.replaceAllMapped(placeholderPattern, (match) {
    final token = '___PM_PH_${index++}___';
    tokens[token] = match.group(0)!;
    return token;
  });

  protected = protected.replaceAll('\n', newlineToken);
  return _ProtectedText(protected, tokens);
}

String _restoreText(String text, Map<String, String> tokens) {
  var restored = text.replaceAll(newlineToken, '\n');
  for (final entry in tokens.entries) {
    restored = restored.replaceAll(entry.key, entry.value);
  }
  return restored;
}

Future<List<String?>> _translateBatchWithRetry(
  String targetLang,
  List<String> batch,
) async {
  Object? lastError;

  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final result = <String?>[];
      for (final text in batch) {
        result.add(await _translateSingle(targetLang, text));
      }

      if (result.length == batch.length) {
        return result;
      }
    } catch (error) {
      lastError = error;
    }

    await Future<void>.delayed(Duration(milliseconds: 1500 * (attempt + 1)));
  }

  throw StateError('batch translation failed after retries: $lastError');
}

Future<String?> _translateSingle(String targetLang, String text) async {
  final query = Uri.https('translate.googleapis.com', '/translate_a/single', {
    'client': 'gtx',
    'sl': 'en',
    'tl': targetLang,
    'dt': 't',
    'q': text,
  });

  final client = HttpClient();
  try {
    final request = await client.getUrl(query);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: query);
    }

    final payload = jsonDecode(body);
    if (payload is! List || payload.isEmpty || payload[0] is! List) {
      throw FormatException('Unexpected translate payload');
    }

    final translatedParts = payload[0] as List;
    final translatedText = translatedParts
        .map((part) => part is List && part.isNotEmpty ? part[0] : null)
        .whereType<String>()
        .join();

    return translatedText;
  } finally {
    client.close(force: true);
  }
}
