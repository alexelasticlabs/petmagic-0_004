import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile avatar rendering checks URLs before network image use', () {
    final hostSource = File(
      'lib/features/profile/presentation/profile_surface_widgets.dart',
    ).readAsStringSync();
    final cardsSource = File(
      'lib/features/profile/presentation/profile_surface_cards.part.dart',
    ).readAsStringSync();
    final identitySource = File(
      'lib/features/profile/presentation/profile_surface_identity.part.dart',
    ).readAsStringSync();
    final metaSource = File(
      'lib/features/profile/presentation/profile_surface_meta.part.dart',
    ).readAsStringSync();
    final source = '$hostSource\n$cardsSource\n$identitySource\n$metaSource';

    expect(hostSource, contains("part 'profile_surface_cards.part.dart';"));
    expect(hostSource, contains("part 'profile_surface_identity.part.dart';"));
    expect(hostSource, contains("part 'profile_surface_meta.part.dart';"));
    expect(
      hostSource,
      isNot(contains('class ProfileAvatarBadge extends StatelessWidget')),
    );
    expect(identitySource, contains("part of 'profile_surface_widgets.dart';"));
    expect(identitySource, contains('class ProfileAvatarBadge'));
    expect(source, contains('parseSafeProfileAvatarUri(imageUrl)'));
    expect(source, contains('imageUrl: safeImageUrl'));
    expect(source, isNot(contains('imageUrl: imageUrl!')));
  });

  test('profile failure logs do not include raw avatar media urls', () {
    final source = File(
      'lib/features/profile/presentation/profile_controller.dart',
    ).readAsStringSync();
    final evictBody = _methodBody(source, 'Future<void> _evictAvatarCache');

    expect(evictBody, contains('parseSafeProfileAvatarUri(imageUrl)'));
    expect(evictBody, contains('evictFromCache(safeImageUrl)'));
    expect(evictBody, contains('NetworkImage(safeImageUrl)'));
    expect(evictBody, isNot(contains('NetworkImage(imageUrl)')));
    expect(evictBody, contains("'avatar_cache_evict_failed'"));
    expect(evictBody, isNot(contains('avatar_url')));
    expect(evictBody, isNot(contains('imageUrl}')));
    expect(evictBody, isNot(contains('imageUrl,')));
  });
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('Could not find $signature');
  }

  final openBrace = source.indexOf('{', start);
  if (openBrace < 0) {
    throw StateError('Could not find body for $signature');
  }

  var depth = 0;
  for (var i = openBrace; i < source.length; i++) {
    final char = source[i];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(openBrace, i + 1);
      }
    }
  }

  throw StateError('Could not parse body for $signature');
}
