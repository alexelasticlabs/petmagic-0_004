import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';

final avatarMediaGatewayProvider = Provider<AvatarMediaGateway>((ref) {
  throw StateError(
    'AvatarMediaGateway is not bound. Add the app composition override.',
  );
});

abstract interface class AvatarMediaGateway {
  Future<LocalMediaFile?> pickAvatarImage();

  Future<void> evictAvatarCache(String imageUrl);

  Future<void> deleteManagedTempFile(String filePath);
}
