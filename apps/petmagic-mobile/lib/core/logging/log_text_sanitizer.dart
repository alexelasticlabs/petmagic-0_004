/// Redacts credentials and personal data embedded in unstructured log text.
final class LogTextSanitizer {
  const LogTextSanitizer._();

  static String maskSensitiveText(String value) {
    var masked = value;

    masked = masked.replaceAllMapped(
      RegExp(
        r'\bAuthorization\s*[:=]\s*([A-Za-z]+\s+)?[^\s,}\]]+',
        caseSensitive: false,
      ),
      (match) {
        final value = match.group(0)!;
        final separator = value.contains(':') ? ':' : '=';
        return 'Authorization$separator ${value.toLowerCase().contains('bearer') ? 'Bearer ***' : '***'}';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["'])(authorization|cookie|set[_-]?cookie)\1(\s*[:=]\s*)(["'])(.*?)\4''',
        caseSensitive: false,
      ),
      (match) {
        final keyQuote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ':';
        final valueQuote = match.group(4) ?? '';
        return '$keyQuote$key$keyQuote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'\b(cookie|set[_-]?cookie)\s*[:=]\s*[^\s,}\]]+',
        caseSensitive: false,
      ),
      (match) {
        final value = match.group(0)!;
        final key = value.split(RegExp(r'\s*[:=]\s*')).first;
        final separator = value.contains(':') ? ':' : '=';
        return '$key$separator ***';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'\b(x[_-]?api[_-]?key|api[_-]?key|x[_-]?fal[_-]?key|fal[_-]?key|stripe[_-]?signature|x[_-]?goog[_-]?signature|x[_-]?webhook[_-]?signature)\s*[:=]\s*[^\s,}\]]+',
        caseSensitive: false,
      ),
      (match) {
        final value = match.group(0)!;
        final key = value.split(RegExp(r'\s*[:=]\s*')).first;
        final separator = value.contains(':') ? ':' : '=';
        return '$key$separator ***';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      (_) => 'Bearer ***',
    );
    masked = masked.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b'),
      (_) => '***',
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)(access[_-]?token|refresh[_-]?token|id[_-]?token|auth[_-]?token|jwt|api[_-]?key|credential|signature|payment[_-]?intent[_-]?client[_-]?secret|payment[_-]?intent[_-]?ids?|setup[_-]?intent[_-]?ids?|client[_-]?secret|secret|password|receipt|signed[_-]?url|checkout[_-]?url|payment[_-]?url|billing[_-]?portal[_-]?url|customer[_-]?portal[_-]?url|redirect[_-]?url|callback[_-]?url|return[_-]?url|success[_-]?url|cancel[_-]?url|user[_-]?ids?|profile[_-]?user[_-]?ids?|owner[_-]?user[_-]?ids?|subject[_-]?ids?|account[_-]?ids?|account[_-]?scope|user[_-]?scope|scope|pet[_-]?ids?|pet[_-]?photo[_-]?ids?|generation[_-]?ids?|template[_-]?ids?|assignment[_-]?ids?|conversation[_-]?ids?|message[_-]?ids?|ticket[_-]?ids?|attachment[_-]?ids?|feedback[_-]?ids?|report[_-]?ids?|moderation[_-]?ids?|order[_-]?ids?|card[_-]?number|cvc|cvv|auth[_-]?ticket|external[_-]?auth[_-]?ticket|ticket|session[_-]?ids?|checkout[_-]?session[_-]?ids?|stripe[_-]?session[_-]?ids?|purchase[_-]?token|purchase[_-]?ids?|server[_-]?verification[_-]?data|local[_-]?verification[_-]?data|verification[_-]?data|signed[_-]?transaction[_-]?info|external[_-]?payment[_-]?ids?|external[_-]?subscription[_-]?ids?|subscription[_-]?ids?|customer[_-]?ids?)\1(\s*[:=]\s*)(["']?)[^}\]\s"']+\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        return '$quote$key$quote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)([a-z0-9_-]*(?:user[_-]?ids?|account[_-]?ids?|pet[_-]?ids?|generation(?:[_-]?result)?[_-]?ids?|template[_-]?ids?|assignment[_-]?ids?|conversation[_-]?ids?|message[_-]?ids?|ticket[_-]?ids?|attachment[_-]?ids?|purchase[_-]?ids?|subscription[_-]?ids?|feedback[_-]?ids?|report[_-]?ids?|moderation[_-]?ids?|order[_-]?ids?))\1(\s*[:=]\s*)(["']?)[^}\]\s"']+\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        return '$quote$key$quote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)(attachment[_-]?urls?|file[_-]?urls?|media[_-]?urls?|image[_-]?urls?|video[_-]?urls?|avatar[_-]?urls?|thumbnail[_-]?urls?|preview[_-]?urls?|output[_-]?urls?|download[_-]?urls?|upload[_-]?urls?)\1(\s*[:=]\s*)(["']?)(https?://[^,}\]\s"']+)\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        final value = match.group(5) ?? '';
        return '$quote$key$quote$separator$valueQuote${maskRemoteMediaUrl(value)}$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)(user[_-]?name|display[_-]?name|full[_-]?name|first[_-]?name|last[_-]?name|sender[_-]?name|sender[_-]?display[_-]?name|recipient[_-]?name|recipient[_-]?display[_-]?name|contact[_-]?name|contact[_-]?display[_-]?name|address|full[_-]?address|street[_-]?address|address[_-]?line1?|address[_-]?line2|city|country|region|province|postal[_-]?code|zip[_-]?code)\1(\s*[:=]\s*)(["']?)[^,}\]\n"']+\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        return '$quote$key$quote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)([a-z0-9_-]*file[_-]?names?)\1(\s*[:=]\s*)(?:(["'])([^"']*)\4|([^}\]\s"']+))''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        return '$quote$key$quote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(
        r'''(["']?)(file[_-]?path|local[_-]?path|source[_-]?path|image[_-]?path|video[_-]?path|avatar[_-]?path)\1(\s*[:=]\s*)(["']?)[^,}\]\s"']+\4''',
        caseSensitive: false,
      ),
      (match) {
        final quote = match.group(1) ?? '';
        final key = match.group(2) ?? '';
        final separator = match.group(3) ?? ': ';
        final valueQuote = match.group(4) ?? '';
        return '$quote$key$quote$separator$valueQuote***$valueQuote';
      },
    );

    masked = masked.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
      (match) {
        final email = match.group(0)!;
        final at = email.indexOf('@');
        return at <= 0 ? '***' : '${email[0]}***${email.substring(at)}';
      },
    );
    masked = masked.replaceAllMapped(
      RegExp(
        r'''(?:file://|/(?:private/)?var/|/data/user/|/storage/emulated/|/sdcard/|/tmp/|[A-Za-z]:\\)[^\s,}\]\)'"]+''',
        caseSensitive: false,
      ),
      (_) => '***',
    );
    masked = masked.replaceAllMapped(
      RegExp(r'https?://[^\s]+[?#][^\s]+', caseSensitive: false),
      (match) {
        final uri = Uri.tryParse(match.group(0)!);
        if (uri == null || (!uri.hasQuery && !uri.hasFragment)) {
          return match.group(0)!;
        }
        return maskUrlQueryAndFragment(uri);
      },
    );
    masked = masked.replaceAllMapped(
      RegExp(r'\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9_]+\b'),
      (_) => '***',
    );
    masked = masked.replaceAllMapped(
      RegExp(
        r'\b(?:pi|seti)_[A-Za-z0-9]+_secret_[A-Za-z0-9_]+\b',
        caseSensitive: false,
      ),
      (_) => '***',
    );
    masked = masked.replaceAllMapped(
      RegExp(r'\bek_(?:live|test)_[A-Za-z0-9_]+\b', caseSensitive: false),
      (_) => '***',
    );
    masked = masked.replaceAllMapped(
      RegExp(r'\bcs_(?:live|test)_[A-Za-z0-9_]+\b', caseSensitive: false),
      (_) => '***',
    );
    masked = masked.replaceAllMapped(
      RegExp(r'\b(?:\+?\d[\d\s().-]{7,}\d)\b'),
      (_) => '***',
    );
    return masked;
  }

  static String maskRemoteMediaUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return '***';
    }
    final hasPath = uri.pathSegments.any((segment) => segment.isNotEmpty);
    final sanitized = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: hasPath ? '/***' : '',
    );
    final normalized = sanitized.toString();
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  static String maskUrlQueryAndFragment(Uri uri) {
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/***',
    ).toString();
  }

  static bool isHttpUrl(Uri uri) {
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static String stripUrlCredentialsQueryAndFragment(Uri uri) {
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString().replaceFirst(RegExp(r'\?$'), '');
  }

  static String normalize(String value) {
    final normalizedControls = value.replaceAll(
      RegExp(r'[\u0000-\u001F\u007F]+'),
      ' ',
    );
    return normalizedControls.replaceAll(RegExp(r' {2,}'), ' ').trim();
  }
}
