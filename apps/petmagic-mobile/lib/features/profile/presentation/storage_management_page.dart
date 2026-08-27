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
  late Future<_StorageUsage> _storageUsage = _loadStorageUsage();
  _StorageCleanupTarget? _clearingTarget;

  Future<_StorageUsage> _loadStorageUsage() async {
    final entries = await ref
        .read(generationGalleryStoreProvider)
        .loadLocalReadyItems();
    final downloadedEntries = entries
        .where((entry) => entry.localBytes > 0)
        .toList(growable: false);
    return _StorageUsage(
      downloadedBytes: downloadedEntries.fold<int>(
        0,
        (total, entry) => total + entry.localBytes,
      ),
      downloadedItems: downloadedEntries.length,
    );
  }

  Future<void> _refreshStorageUsage({bool showFailure = false}) async {
    final storageUsage = _loadStorageUsage();
    setState(() {
      _storageUsage = storageUsage;
    });

    try {
      await storageUsage;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Profile.StorageManagement',
        operation: 'refresh_storage_usage',
        message: 'Unable to refresh local storage usage',
        error: error,
        stackTrace: stackTrace,
      );
      if (showFailure && mounted) {
        PetMagicToast.show(
          context,
          message: AppLocalizations.of(
            context,
          ).profileSettingsUnavailableSubtitle,
          tone: PetMagicToastTone.warning,
        );
      }
    }
  }

  Future<void> _clearMediaCache() => _clear(
    target: _StorageCleanupTarget.mediaCache,
    confirmationTitle: (text) => text.profileStorageClearMediaConfirmTitle,
    confirmationBody: (text) => text.profileStorageClearMediaConfirmBody,
    action: AppMediaCacheManager.clearAll,
  );

  Future<void> _clearDownloadedGenerations() => _clear(
    target: _StorageCleanupTarget.downloadedWorks,
    confirmationTitle: (text) => text.profileStorageClearDownloadsConfirmTitle,
    confirmationBody: (text) => text.profileStorageClearDownloadsConfirmBody,
    action: () =>
        ref.read(generationGalleryStoreProvider).clearCurrentAccountDownloads(),
  );

  Future<void> _clear({
    required _StorageCleanupTarget target,
    required String Function(AppLocalizations text) confirmationTitle,
    required String Function(AppLocalizations text) confirmationBody,
    required Future<void> Function() action,
  }) async {
    if (_clearingTarget != null) {
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

    setState(() => _clearingTarget = target);
    try {
      await action();
      if (!mounted) {
        return;
      }
      await _refreshStorageUsage();
      if (!mounted) {
        return;
      }
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
        setState(() => _clearingTarget = null);
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
        child: RefreshIndicator(
          color: colors.accent,
          onRefresh: _refreshStorageUsage,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
            children: [
              ProfileSettingsDetailHeader(
                title: text.profileSettingsStorageTitle,
                subtitle: text.profileSettingsStorageSubtitle,
              ),
              const SizedBox(height: 22),
              ProfileSectionLabel(label: text.profileStorageUsageSection),
              FutureBuilder<_StorageUsage>(
                future: _storageUsage,
                builder: (context, snapshot) {
                  final usage = snapshot.data;
                  final isLoading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final hasError = snapshot.hasError;

                  return PetMagicAccentCard(
                    accentColor: colors.accent,
                    glowAlignment: Alignment.topRight,
                    glowRadius: 1.1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: colors.accentSoft.withValues(
                                  alpha: 0.35,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.download_for_offline_rounded,
                                color: colors.accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                text.profileStorageDownloadedTitle,
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: text.profileNotificationsRefreshStatus,
                              onPressed: isLoading
                                  ? null
                                  : () =>
                                        _refreshStorageUsage(showFailure: true),
                              icon: isLoading
                                  ? SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        color: colors.accent,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.refresh_rounded,
                                      color: colors.accent,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: AppTheme.motionFast,
                          child: Text(
                            hasError
                                ? '—'
                                : usage == null
                                ? '…'
                                : _formatBytes(usage.downloadedBytes),
                            key: ValueKey<String>(
                              '$hasError:${usage?.downloadedBytes}',
                            ),
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasError
                              ? text.profileSettingsUnavailableSubtitle
                              : text.profileStorageDownloadedItems(
                                  usage?.downloadedItems ?? 0,
                                ),
                          style: TextStyle(
                            color: colors.textSoft,
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
                        isLoading:
                            _clearingTarget == _StorageCleanupTarget.mediaCache,
                        isDisabled: _clearingTarget != null,
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
                        isLoading:
                            _clearingTarget ==
                            _StorageCleanupTarget.downloadedWorks,
                        isDisabled: _clearingTarget != null,
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
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({
    required this.label,
    required this.isLoading,
    required this.isDisabled,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final bool isDisabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return TextButton.icon(
      onPressed: isDisabled ? null : onPressed,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_sweep_outlined, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

enum _StorageCleanupTarget { mediaCache, downloadedWorks }

class _StorageUsage {
  const _StorageUsage({
    required this.downloadedBytes,
    required this.downloadedItems,
  });

  final int downloadedBytes;
  final int downloadedItems;
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
