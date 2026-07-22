import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

void main() {
  test('profile avatar cache keys strip signed URL secrets', () {
    final safeUrl = persistentSafeProfileAvatarUrl(
      'https://cdn.petmagic.app/profile/avatars/cat.jpg?X-Amz-Signature=secret&token=raw#viewer',
    );

    expect(safeUrl, 'https://cdn.petmagic.app/profile/avatars/cat.jpg');
    expect(safeUrl, isNot(contains('X-Amz-Signature')));
    expect(safeUrl, isNot(contains('token=raw')));
    expect(safeUrl, isNot(contains('viewer')));
  });

  test('profile avatar rendering checks URLs before network image use', () {
    final hostSource = File(
      'lib/shared/profile/profile_surface_widgets.dart',
    ).readAsStringSync();
    final cardsSource = File(
      'lib/shared/profile/profile_surface_cards.part.dart',
    ).readAsStringSync();
    final identitySource = File(
      'lib/shared/profile/profile_surface_identity.part.dart',
    ).readAsStringSync();
    final metaSource = File(
      'lib/shared/profile/profile_surface_meta.part.dart',
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
    expect(source, contains('cacheKey: persistentSafeProfileAvatarUrl('));
    expect(source, contains('memCacheWidth: avatarCacheSize'));
    expect(source, contains('memCacheHeight: avatarCacheSize'));
    expect(source, contains('maxWidthDiskCache: avatarCacheSize'));
    expect(source, contains('maxHeightDiskCache: avatarCacheSize'));
    expect(source, isNot(contains('imageUrl: imageUrl!')));
  });

  test('profile failure logs do not include raw avatar media urls', () {
    final source = File(
      'lib/features/profile/application/profile_avatar_coordinator.dart',
    ).readAsStringSync();
    final gatewaySource = File(
      'lib/features/profile/data/mobile_avatar_media_gateway.dart',
    ).readAsStringSync();
    final evictBody = _methodBody(source, 'Future<void> _evictAvatarCache');

    expect(evictBody, contains('parseSafeProfileAvatarUri(imageUrl)'));
    expect(
      gatewaySource,
      contains('final cacheKey = persistentSafeProfileAvatarUrl(imageUrl);'),
    );
    expect(
      gatewaySource,
      contains('evictFromCache(imageUrl, cacheKey: cacheKey)'),
    );
    expect(gatewaySource, isNot(contains('evictFromCache(imageUrl);')));
    expect(gatewaySource, contains('NetworkImage(imageUrl)'));
    expect(evictBody, contains('_mediaGateway.evictAvatarCache(safeImageUrl)'));
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
