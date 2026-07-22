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
  void didUpdateWidget(covariant _SupportAttachmentPickerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      oldWidget.scrollController.removeListener(_onGridScrolled);
      widget.scrollController.addListener(_onGridScrolled);
    }
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
      _hasMore = false;
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
      _hasMore = fetched.length == _supportAttachmentRecentAssetCount;
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
  Widget build(BuildContext context) => _buildContent(context);
}
