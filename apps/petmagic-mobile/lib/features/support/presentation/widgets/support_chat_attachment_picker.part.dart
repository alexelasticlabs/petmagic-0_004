part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportAttachmentPickerSheet extends StatefulWidget {
  const _SupportAttachmentPickerSheet({
    required this.scrollController,
    required this.selectedAssetIds,
    required this.selectedAssetOrderById,
    required this.onSendSelected,
  });

  final ScrollController scrollController;
  final Set<String> selectedAssetIds;
  final Map<String, int> selectedAssetOrderById;
  final Future<bool> Function(List<AssetEntity> assets, String caption)
  onSendSelected;

  @override
  State<_SupportAttachmentPickerSheet> createState() =>
      _SupportAttachmentPickerSheetState();
}

class _SupportAttachmentPickerSheetState
    extends State<_SupportAttachmentPickerSheet> {
  final TextEditingController _captionController = TextEditingController();
  final AppPermissionCoordinator _permissionCoordinator =
      AppPermissionCoordinator();
  late Map<String, int> _selectedAssetOrderById;
  final Map<String, AssetEntity> _selectedAssetsById = <String, AssetEntity>{};
  PermissionState? _permissionState;
  AssetPathEntity? _recentAlbum;
  List<AssetEntity> _assets = const [];
  int _nextPage = 0;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSendingSelection = false;
  bool _assetLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _selectedAssetOrderById = {...widget.selectedAssetOrderById};
    if (_selectedAssetOrderById.isEmpty && widget.selectedAssetIds.isNotEmpty) {
      _selectedAssetOrderById = {
        for (var index = 0; index < widget.selectedAssetIds.length; index++)
          widget.selectedAssetIds.elementAt(index): index + 1,
      };
    }
    widget.scrollController.addListener(_onGridScrolled);
    unawaited(_initializeAssets());
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onGridScrolled);
    _captionController.dispose();
    super.dispose();
  }

  void _onGridScrolled() {
    if (!widget.scrollController.hasClients ||
        widget.scrollController.position.extentAfter > 420) {
      return;
    }
    unawaited(_loadNextPage());
  }

  Future<void> _initializeAssets() async {
    _assetLoadFailed = false;
    final galleryPermissionGranted =
        await _requestMixedMediaGalleryPermission();
    if (!mounted) {
      return;
    }
    if (!galleryPermissionGranted) {
      setState(() {
        _permissionState = null;
        _isInitialLoading = false;
        _assets = const [];
        _hasMore = false;
      });
      return;
    }

    late final PermissionState permission;
    try {
      permission = await PhotoManager.requestPermissionExtend();
    } on Object {
      _markAssetLoadFailed(clearAssets: true);
      return;
    }
    if (!mounted) {
      return;
    }

    if (!permission.hasAccess) {
      setState(() {
        _permissionState = permission;
        _isInitialLoading = false;
        _assets = const [];
        _hasMore = false;
      });
      return;
    }

    late final List<AssetPathEntity> paths;
    try {
      paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: const [
            OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
    } on Object {
      _markAssetLoadFailed(clearAssets: true);
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionState = permission;
      _recentAlbum = paths.isEmpty ? null : paths.first;
      _isInitialLoading = false;
      _assets = const [];
      _nextPage = 0;
      _hasMore = paths.isNotEmpty;
      _assetLoadFailed = false;
    });

    if (_recentAlbum == null) {
      return;
    }

    await _loadNextPage(reset: true);
  }

  Future<bool> _requestMixedMediaGalleryPermission() async {
    final photosPermission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.photos,
    );
    if (!mounted || !photosPermission.granted) {
      return false;
    }

    if (!Platform.isAndroid) {
      return true;
    }

    final videosPermission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.videos,
    );
    return mounted && videosPermission.granted;
  }

  Future<void> _loadNextPage({bool reset = false}) async {
    if (_isLoadingMore || _recentAlbum == null || (!_hasMore && !reset)) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      if (reset) {
        _assets = const [];
        _nextPage = 0;
        _hasMore = true;
      }
    });

    final currentPage = _nextPage;
    late final List<AssetEntity> fetched;
    try {
      fetched = await _recentAlbum!.getAssetListPaged(
        page: currentPage,
        size: _supportAttachmentRecentAssetCount,
      );
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        if (reset) {
          _assets = const [];
        }
        _isInitialLoading = false;
        _isLoadingMore = false;
        _hasMore = false;
        _assetLoadFailed = _assets.isEmpty;
      });
      return;
    }
    final nextAssets = fetched
        .where(
          (asset) =>
              asset.type == AssetType.image || asset.type == AssetType.video,
        )
        .toList(growable: false);
    if (!mounted) {
      return;
    }

    setState(() {
      final merged = <AssetEntity>[..._assets];
      final knownIds = merged.map((asset) => asset.id).toSet();
      for (final asset in nextAssets) {
        if (knownIds.add(asset.id)) {
          merged.add(asset);
        }
      }
      _assets = merged;
      for (final asset in merged) {
        if (_selectedAssetOrderById.containsKey(asset.id)) {
          _selectedAssetsById[asset.id] = asset;
        }
      }
      _nextPage = currentPage + 1;
      _hasMore = nextAssets.length == _supportAttachmentRecentAssetCount;
      _isLoadingMore = false;
      _assetLoadFailed = false;
    });
  }

  void _markAssetLoadFailed({required bool clearAssets}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionState = null;
      _recentAlbum = null;
      if (clearAssets) {
        _assets = const [];
      }
      _nextPage = 0;
      _isInitialLoading = false;
      _isLoadingMore = false;
      _hasMore = false;
      _assetLoadFailed = true;
    });
  }

  void _retryInitializeAssets() {
    if (_isInitialLoading || _isLoadingMore) {
      return;
    }

    setState(() {
      _permissionState = null;
      _recentAlbum = null;
      _assets = const [];
      _nextPage = 0;
      _isInitialLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _assetLoadFailed = false;
    });
    unawaited(_initializeAssets());
  }

  void _toggleAsset(AssetEntity asset) {
    final wasSelected = _selectedAssetOrderById.containsKey(asset.id);
    HapticFeedback.selectionClick();
    setState(() {
      if (wasSelected) {
        final removedOrder = _selectedAssetOrderById.remove(asset.id);
        _selectedAssetsById.remove(asset.id);
        if (removedOrder != null) {
          _selectedAssetOrderById = {
            for (final entry in _selectedAssetOrderById.entries)
              entry.key: entry.value > removedOrder
                  ? entry.value - 1
                  : entry.value,
          };
        }
      } else {
        if (_selectedAssetOrderById.length >= _supportAttachmentMaxCount) {
          PetMagicToast.show(
            context,
            message: AppLocalizations.of(
              context,
            ).supportChatTooManyAttachmentsError,
            tone: PetMagicToastTone.warning,
          );
          return;
        }
        final nextOrder = _selectedAssetOrderById.isEmpty
            ? 1
            : _selectedAssetOrderById.values.reduce(math.max) + 1;
        _selectedAssetOrderById[asset.id] = nextOrder;
        _selectedAssetsById[asset.id] = asset;
      }
    });
  }

  Future<void> _sendSelected() async {
    if (_isSendingSelection || _selectedAssetOrderById.isEmpty) {
      return;
    }

    setState(() {
      _isSendingSelection = true;
    });
    final orderedEntries = _selectedAssetOrderById.entries.toList(
      growable: false,
    )..sort((left, right) => left.value.compareTo(right.value));
    final selectedAssets = orderedEntries
        .map((entry) => _selectedAssetsById[entry.key])
        .whereType<AssetEntity>()
        .toList(growable: false);
    final wasSent = await widget.onSendSelected(
      selectedAssets,
      _captionController.text,
    );
    if (!mounted) {
      return;
    }

    if (wasSent) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSendingSelection = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 420;
    final hasAccess = _permissionState?.hasAccess ?? false;
    final isLimitedAccess =
        Platform.isIOS && (_permissionState?.isLimited ?? false);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceStrong,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text.supportChatRecentMediaTitle,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (isLimitedAccess)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.34),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text.supportChatAttachmentLimitedAccessHint,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: PhotoManager.openSetting,
                        child: Text(text.supportChatOpenSettingsAction),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : _assetLoadFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            text.supportChatUnavailableError,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _retryInitializeAssets,
                            child: Text(text.retryAction),
                          ),
                        ],
                      ),
                    ),
                  )
                : !hasAccess
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            text.supportChatAttachmentNoGalleryAccessError,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: PhotoManager.openSetting,
                            child: Text(text.supportChatOpenSettingsAction),
                          ),
                        ],
                      ),
                    ),
                  )
                : _assets.isEmpty
                ? Center(
                    child: Text(
                      text.supportChatAttachmentNoRecentMedia,
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                  )
                : GridView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 4 : 3,
                      crossAxisSpacing: 1.5,
                      mainAxisSpacing: 1.5,
                    ),
                    itemCount: _assets.length + 2 + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _SupportRecentCameraTile(
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_SupportAttachmentQuickAction.camera),
                        );
                      }

                      if (index == 1) {
                        return _SupportRecentFilesTile(
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_SupportAttachmentQuickAction.files),
                        );
                      }

                      final assetIndex = index - 2;
                      if (assetIndex >= _assets.length) {
                        return const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final asset = _assets[assetIndex];
                      return _SupportRecentAssetTile(
                        asset: asset,
                        selectedOrder: _selectedAssetOrderById[asset.id],
                        onTap: () => _toggleAsset(asset),
                      );
                    },
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 170),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              );
            },
            child: _selectedAssetOrderById.isEmpty
                ? const SizedBox.shrink(
                    key: ValueKey<String>('picker-send-empty'),
                  )
                : Padding(
                    key: const ValueKey<String>('picker-send-active'),
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _captionController,
                                enabled: !_isSendingSelection,
                                minLines: 1,
                                maxLines: 2,
                                style: TextStyle(
                                  color: colors.textStrong,
                                  fontSize: 14,
                                  height: 1.32,
                                ),
                                decoration: InputDecoration(
                                  hintText: text.supportChatInputHint,
                                  hintStyle: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 13.5,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: _isSendingSelection
                                  ? _supportComposerSendGreen(
                                      context,
                                    ).withValues(alpha: 0.85)
                                  : _supportComposerSendGreen(context),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _isSendingSelection
                                    ? null
                                    : _sendSelected,
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: _isSendingSelection
                                        ? const SizedBox(
                                            width: 17,
                                            height: 17,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 22,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupportRecentAssetTile extends StatefulWidget {
  const _SupportRecentAssetTile({
    required this.asset,
    required this.selectedOrder,
    required this.onTap,
  });

  final AssetEntity asset;
  final int? selectedOrder;
  final VoidCallback onTap;

  @override
  State<_SupportRecentAssetTile> createState() =>
      _SupportRecentAssetTileState();
}

class _SupportRecentAssetTileState extends State<_SupportRecentAssetTile> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
      quality: 85,
    );
  }

  @override
  void didUpdateWidget(covariant _SupportRecentAssetTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumbnailFuture = widget.asset.thumbnailDataWithSize(
        const ThumbnailSize(300, 300),
        quality: 85,
      );
    }
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isVideo = widget.asset.type == AssetType.video;
    final isSelected = widget.selectedOrder != null;
    return AnimatedScale(
      scale: isSelected ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<Uint8List?>(
                  future: _thumbnailFuture,
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return ColoredBox(
                        color: colors.surface,
                        child: Center(
                          child: Icon(
                            isVideo
                                ? Icons.videocam_outlined
                                : Icons.image_not_supported_outlined,
                            color: colors.textMuted,
                          ),
                        ),
                      );
                    }
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      cacheWidth: _supportRecentMediaThumbnailCacheExtent,
                      cacheHeight: _supportRecentMediaThumbnailCacheExtent,
                      filterQuality: FilterQuality.medium,
                    );
                  },
                ),
                if (isVideo)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.42),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isVideo)
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                if (isVideo)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          _formatDuration(widget.asset.videoDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: isSelected ? 1 : 0,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? _supportComposerSendGreen(context)
                          : Colors.black.withValues(alpha: 0.38),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Text(
                              '${widget.selectedOrder}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportRecentCameraTile extends StatelessWidget {
  const _SupportRecentCameraTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.border.withValues(alpha: 0.9)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_camera_rounded,
                color: colors.textStrong,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                text.supportChatTakePhotoAction,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportRecentFilesTile extends StatelessWidget {
  const _SupportRecentFilesTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.border.withValues(alpha: 0.9)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                color: colors.textStrong,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                text.supportChatAttachFileAction,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
