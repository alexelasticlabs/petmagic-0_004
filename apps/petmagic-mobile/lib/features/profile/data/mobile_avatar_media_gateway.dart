import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/features/profile/application/avatar_media_gateway.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/files/temp_media_cleanup.dart';

final mobileAvatarMediaGatewayProvider = Provider<AvatarMediaGateway>((ref) {
  return MobileAvatarMediaGateway();
});

final class MobileAvatarMediaGateway implements AvatarMediaGateway {
  MobileAvatarMediaGateway({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  static const _managedAvatarTempFilePrefix = 'petmagic_avatar_';

  final ImagePicker _imagePicker;

  @override
  Future<LocalMediaFile?> pickAvatarImage() async {
    final selected = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (selected == null) {
      return null;
    }

    return LocalMediaFile(
      path: selected.path,
      name: selected.name,
      mimeType: selected.mimeType,
    );
  }

  @override
  Future<void> evictAvatarCache(String imageUrl) async {
    final cacheKey = persistentSafeProfileAvatarUrl(imageUrl);
    await CachedNetworkImage.evictFromCache(imageUrl, cacheKey: cacheKey);
    imageCache.evict(NetworkImage(imageUrl));
  }

  @override
  Future<void> deleteManagedTempFile(String filePath) async {
    if (!_isManagedAvatarTempFile(filePath)) {
      return;
    }

    await TempMediaCleanup.deleteIfExists(File(filePath));
  }

  bool _isManagedAvatarTempFile(String filePath) {
    final segments = Uri.file(filePath).pathSegments;
    final fileName = segments.isEmpty ? filePath : segments.last;
    if (!fileName.startsWith(_managedAvatarTempFilePrefix)) {
      return false;
    }

    final normalizedPath = _normalizedFilePath(filePath);
    final normalizedTempRoot = _normalizedDirectoryPath(
      Directory.systemTemp.path,
    );
    return normalizedPath.startsWith(normalizedTempRoot);
  }

  String _normalizedFilePath(String value) {
    return value.replaceAll('\\', '/').toLowerCase();
  }

  String _normalizedDirectoryPath(String value) {
    final normalized = _normalizedFilePath(value);
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }
}
