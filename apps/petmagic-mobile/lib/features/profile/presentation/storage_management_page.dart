import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/app_media_cache_manager.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/profile_settings_detail_header.dart';
import 'package:petmagic_mobile/features/templates/application/generation_gallery_cache.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

/// Lets a signed-in user remove only reproducible data stored on this device.
class StorageManagementPage extends ConsumerStatefulWidget {
  const StorageManagementPage({super.key});

  static const routePath = '/profile/settings/storage';

  @override
  ConsumerState<StorageManagementPage> createState() =>
      _StorageManagementPageState();
}

class _StorageManagementPageState extends ConsumerState<StorageManagementPage> {
  late Future<int> _downloadedBytes = _loadDownloadedBytes();
  bool _isClearing = false;

  Future<int> _loadDownloadedBytes() async {
    final entries = await ref
        .read(generationGalleryStoreProvider)
        .loadLocalReadyItems();
    return entries.fold<int>(
      0,
      (total, entry) => total + (entry.localBytes < 0 ? 0 : entry.localBytes),
    );
  }

  void _refreshStorageUsage() {
    setState(() {
      _downloadedBytes = _loadDownloadedBytes();
    });
  }

  Future<void> _clearMediaCache() => _clear(
    confirmationTitle: (text) => text.profileStorageClearMediaConfirmTitle,
    confirmationBody: (text) => text.profileStorageClearMediaConfirmBody,
    action: AppMediaCacheManager.clearAll,
  );

  Future<void> _clearDownloadedGenerations() => _clear(
    confirmationTitle: (text) => text.profileStorageClearDownloadsConfirmTitle,
    confirmationBody: (text) => text.profileStorageClearDownloadsConfirmBody,
    action: () =>
        ref.read(generationGalleryStoreProvider).clearCurrentAccountDownloads(),
  );

  Future<void> _clear({
    required String Function(AppLocalizations text) confirmationTitle,
    required String Function(AppLocalizations text) confirmationBody,
    required Future<void> Function() action,
  }) async {
    if (_isClearing) {
      return;
    }

    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(confirmationTitle(text)),
        content: Text(confirmationBody(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(text.walletRedeemCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(text.profileStorageClearAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isClearing = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      _refreshStorageUsage();
      PetMagicToast.show(
        context,
        message: text.profileStorageClearSuccess,
        tone: PetMagicToastTone.success,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Profile.StorageManagement',
        operation: 'clear_local_storage',
        message: 'Unable to clear local storage',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        PetMagicToast.show(
          context,
          message: text.profileSettingsUnavailableSubtitle,
          tone: PetMagicToastTone.warning,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

    return ProfileScreenBackground(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
          children: [
            ProfileSettingsDetailHeader(
              title: text.profileSettingsStorageTitle,
              subtitle: text.profileSettingsStorageSubtitle,
            ),
            const SizedBox(height: 22),
            ProfileSectionLabel(label: text.profileStorageUsageSection),
            ProfileGlassCard(
              child: FutureBuilder<int>(
                future: _downloadedBytes,
                builder: (context, snapshot) {
                  final bytes = snapshot.data ?? 0;
                  return Row(
                    children: [
                      Icon(
                        Icons.download_for_offline_outlined,
                        color: colors.accent,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text.profileStorageDownloadedTitle,
                              style: TextStyle(
                                color: colors.textStrong,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              text.profileStorageDownloadedSubtitle(
                                _formatBytes(bytes),
                              ),
                              style: TextStyle(
                                color: colors.textSoft,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            ProfileSectionLabel(label: text.profileStorageCleanupSection),
            ProfileGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ProfileSettingsRow(
                    icon: Icons.cached_rounded,
                    title: text.profileStorageMediaCacheTitle,
                    subtitle: text.profileStorageMediaCacheSubtitle,
                    trailing: _ClearButton(
                      label: text.profileStorageClearAction,
                      isLoading: _isClearing,
                      onPressed: _clearMediaCache,
                    ),
                  ),
                  ProfileSettingsRow(
                    icon: Icons.folder_delete_outlined,
                    title: text.profileStorageDownloadedTitle,
                    subtitle: text.profileStorageDownloadedClearSubtitle,
                    showDivider: false,
                    trailing: _ClearButton(
                      label: text.profileStorageClearAction,
                      isLoading: _isClearing,
                      onPressed: _clearDownloadedGenerations,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              text.profileStorageSafetyNote,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
