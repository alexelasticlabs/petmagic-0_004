part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

extension _SupportChatPageActions on _SupportChatPageState {
  Future<void> _pickCameraPhotoAttachmentImpl() async {
    if (!_canAddMoreAttachments()) {
      return;
    }
    final permission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.camera,
    );
    if (!permission.granted) {
      if (mounted) {
        final text = AppLocalizations.of(context);
        _showSupportToast(
          text.supportChatCameraPermissionPhotoError,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) {
      return;
    }

    final attachment = await _validatePickedAttachmentImpl(picked);
    if (attachment == null || !mounted) {
      return;
    }

    _applyState(() {
      _pendingAttachments = [..._pendingAttachments, attachment];
    });
  }

  Future<void> _pickCameraVideoAttachmentImpl() async {
    if (!_canAddMoreAttachments()) {
      return;
    }
    final permission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.camera,
    );
    if (!permission.granted) {
      if (mounted) {
        final text = AppLocalizations.of(context);
        _showSupportToast(
          text.supportChatCameraPermissionVideoError,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final picked = await _imagePicker.pickVideo(
      source: ImageSource.camera,
      maxDuration: _supportAttachmentVideoMaxDuration,
    );
    if (picked == null || !mounted) {
      return;
    }

    final attachment = await _validatePickedAttachmentImpl(picked);
    if (attachment == null || !mounted) {
      return;
    }

    _applyState(() {
      _pendingAttachments = [..._pendingAttachments, attachment];
    });
  }

  Future<void> _pickCameraMediaFromTileImpl() async {
    final action = await showModalBottomSheet<_SupportAttachmentQuickAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        final colors = context.petMagicColors;
        final bottomInset = petMagicScrollableBottomInset(dialogContext);
        final text = AppLocalizations.of(dialogContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.border.withValues(alpha: 0.85)),
              ),
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(text.supportChatTakePhotoAction),
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(_SupportAttachmentQuickAction.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam_outlined),
                    title: Text(text.supportChatRecordVideoAction),
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(_SupportAttachmentQuickAction.video),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }

    if (action == _SupportAttachmentQuickAction.camera) {
      await _pickCameraPhotoAttachmentImpl();
      return;
    }

    if (action == _SupportAttachmentQuickAction.video) {
      await _pickCameraVideoAttachmentImpl();
    }
  }

  Future<void> _pickFileAttachmentsImpl() async {
    if (!_canAddMoreAttachments()) {
      return;
    }
    final permission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.files,
    );
    if (!permission.granted) {
      if (mounted) {
        final text = AppLocalizations.of(context);
        _showSupportToast(
          text.supportChatFilesPermissionError,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final remainingSlots =
        _supportAttachmentMaxCount - _pendingAttachments.length;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'mp4',
        'm4v',
        'mov',
        'qt',
      ],
    );
    final files = picked?.files;
    if (files == null || files.isEmpty || !mounted) {
      return;
    }
    if (files.length > remainingSlots) {
      _showSupportToast(
        AppLocalizations.of(context).supportChatTooManyAttachmentsError,
        tone: PetMagicToastTone.warning,
      );
    }

    final nextAttachments = <_PendingSupportAttachment>[];
    for (final file in files.take(remainingSlots)) {
      final path = file.path;
      if (path == null) {
        continue;
      }

      final attachment = await _validateAttachmentCandidateImpl(
        filePath: path,
        fileName: file.name,
      );
      if (attachment != null) {
        nextAttachments.add(attachment);
      }

      if (!mounted) {
        return;
      }
    }

    if (nextAttachments.isEmpty) {
      return;
    }

    _applyState(() {
      _pendingAttachments = [..._pendingAttachments, ...nextAttachments];
    });
  }

  bool _canAddMoreAttachments() {
    if (_pendingAttachments.length < _supportAttachmentMaxCount) {
      return true;
    }

    _showSupportToast(
      AppLocalizations.of(context).supportChatTooManyAttachmentsError,
      tone: PetMagicToastTone.warning,
    );
    return false;
  }

  Future<_PendingSupportAttachment?> _validatePickedAttachmentImpl(
    XFile picked,
  ) async {
    return _validateAttachmentCandidateImpl(
      filePath: picked.path,
      fileName: picked.name,
    );
  }

  Future<_PendingSupportAttachment?> _validateAttachmentCandidateImpl({
    required String filePath,
    required String fileName,
    Duration? videoDuration,
    String? sourceAssetId,
  }) async {
    final contentType = _controller.resolveContentTypeForUpload(filePath);
    int fileSizeBytes = 0;
    try {
      fileSizeBytes = await File(filePath).length();
    } on Exception {
      // If file size cannot be resolved on this platform, rely on backend validation.
    }
    if (!mounted) {
      return null;
    }

    var resolvedVideoDuration = videoDuration;
    final isVideoCandidate = SupportAttachmentValidation.videoMimeTypes
        .contains(contentType.toLowerCase());
    if (isVideoCandidate && resolvedVideoDuration == null) {
      resolvedVideoDuration = await _resolveVideoDurationFromFileImpl(filePath);
      if (!mounted) {
        return null;
      }
    }

    final validationResult = SupportAttachmentValidation.validate(
      contentType: contentType,
      fileSizeBytes: fileSizeBytes,
      imageMaxBytes: _supportAttachmentImageMaxFileSizeBytes,
      videoMaxBytes: _supportAttachmentVideoMaxFileSizeBytes,
      videoMaxDuration: _supportAttachmentVideoMaxDuration,
      videoDuration: resolvedVideoDuration,
    );

    if (!validationResult.isAllowed) {
      _showAttachmentValidationErrorImpl(validationResult.error);
      return null;
    }

    return _PendingSupportAttachment(
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
      isVideo: validationResult.isVideo,
      sourceAssetId: sourceAssetId,
    );
  }

  Future<Duration?> _resolveVideoDurationFromFileImpl(String filePath) async {
    final controller = VideoPlayerController.file(File(filePath));
    try {
      await controller.initialize();
      return controller.value.duration;
    } on Exception {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  void _showAttachmentValidationErrorImpl(
    SupportAttachmentValidationError? error,
  ) {
    if (!mounted || error == null) {
      return;
    }

    final text = AppLocalizations.of(context);
    final message = switch (error) {
      SupportAttachmentValidationError.unsupportedFormat =>
        text.supportChatAttachmentUnsupportedFormatError,
      SupportAttachmentValidationError.fileTooLarge =>
        text.supportChatAttachmentTooLargeError,
      SupportAttachmentValidationError.videoTooLong =>
        text.supportChatAttachmentVideoTooLongError,
    };
    _showSupportToast(message, tone: PetMagicToastTone.warning);
  }

  Future<void> _showAttachmentOptionsImpl() async {
    if (ref.read(supportChatControllerProvider).isSending) {
      return;
    }

    FocusScope.of(context).unfocus();
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final action = await showModalBottomSheet<_SupportAttachmentQuickAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        final keyboardInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: DraggableScrollableSheet(
            expand: false,
            minChildSize: 0.45,
            initialChildSize: 0.52,
            maxChildSize: 0.98,
            snap: true,
            snapSizes: const [0.52, 0.98],
            builder: (context, scrollController) {
              return _SupportAttachmentPickerSheet(
                scrollController: scrollController,
                selectedAssetIds: _pendingAttachments
                    .map((attachment) => attachment.sourceAssetId)
                    .whereType<String>()
                    .toSet(),
                selectedAssetOrderById: {
                  for (
                    var index = 0;
                    index < _pendingAttachments.length;
                    index++
                  )
                    if (_pendingAttachments[index].sourceAssetId != null)
                      _pendingAttachments[index].sourceAssetId!: index + 1,
                },
                onSendSelected: (assets, caption) =>
                    _sendSelectedAssetsFromPickerImpl(
                      assets: assets,
                      localeTag: localeTag,
                      caption: caption,
                    ),
              );
            },
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _SupportAttachmentQuickAction.camera:
        await _pickCameraMediaFromTileImpl();
        return;
      case _SupportAttachmentQuickAction.files:
        await _pickFileAttachmentsImpl();
        return;
      case _SupportAttachmentQuickAction.video:
        return;
    }
  }

  Future<void> _sendCurrentMessageImpl(String localeTag) async {
    if (_hasPendingAttachment) {
      await _sendPendingAttachmentsImpl(localeTag);
      return;
    }

    final body = _messageController.text;
    final wasSent = await _controller.sendMessage(
      body,
      localeTag: localeTag,
      replyToMessageId: _replyToMessage?.messageId,
    );
    if (!mounted || !wasSent) {
      return;
    }

    if (body.trim().isNotEmpty) {
      _messageController.clear();
    }
    _applyState(() {
      _replyToMessage = null;
    });
  }

  Future<void> _sendPendingAttachmentsImpl(String localeTag) async {
    final pendingAttachments = [..._pendingAttachments];
    if (pendingAttachments.isEmpty) {
      return;
    }

    final body = _messageController.text;
    final wasSent = await _controller.sendAttachments(
      attachments: pendingAttachments
          .map(
            (attachment) => SupportChatUploadAttachment(
              filePath: attachment.filePath,
              fileName: attachment.fileName,
              contentType: attachment.contentType,
            ),
          )
          .toList(growable: false),
      localeTag: localeTag,
      body: body,
      replyToMessageId: _replyToMessage?.messageId,
    );
    if (!mounted || !wasSent) {
      return;
    }

    _messageController.clear();
    _applyState(() {
      _pendingAttachments = const [];
      _replyToMessage = null;
    });
  }

  Future<bool> _sendSelectedAssetsFromPickerImpl({
    required List<AssetEntity> assets,
    required String localeTag,
    required String caption,
  }) async {
    if (assets.isEmpty) {
      return false;
    }

    final nextAttachments = <_PendingSupportAttachment>[];
    for (final asset in assets.take(_supportAttachmentMaxCount)) {
      final file = await asset.file;
      if (file == null) {
        continue;
      }

      final attachment = await _validateAttachmentCandidateImpl(
        filePath: file.path,
        fileName: asset.title ?? file.uri.pathSegments.last,
        videoDuration: asset.type == AssetType.video
            ? asset.videoDuration
            : null,
        sourceAssetId: asset.id,
      );
      if (attachment != null) {
        nextAttachments.add(attachment);
      }

      if (!mounted) {
        return false;
      }
    }

    if (nextAttachments.isEmpty) {
      return false;
    }

    final composerBody = _messageController.text.trim();
    final captionBody = caption.trim();
    final body = captionBody.isNotEmpty ? captionBody : composerBody;
    final wasSent = await _controller.sendAttachments(
      attachments: nextAttachments
          .map(
            (attachment) => SupportChatUploadAttachment(
              filePath: attachment.filePath,
              fileName: attachment.fileName,
              contentType: attachment.contentType,
            ),
          )
          .toList(growable: false),
      localeTag: localeTag,
      body: body,
      replyToMessageId: _replyToMessage?.messageId,
    );
    if (!mounted || !wasSent) {
      return false;
    }

    _messageController.clear();
    _applyState(() {
      _pendingAttachments = const [];
      _replyToMessage = null;
    });
    return true;
  }

  void _removePendingAttachmentImpl(int index) {
    if (index < 0 || index >= _pendingAttachments.length) {
      return;
    }

    _applyState(() {
      _pendingAttachments = [
        for (var i = 0; i < _pendingAttachments.length; i++)
          if (i != index) _pendingAttachments[i],
      ];
    });
  }

  Future<void> _retryAttachmentForMessageImpl(
    SupportChatMessage message,
  ) async {
    if (message.messageId.isEmpty || !message.canRetryAttachment) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'mp4',
        'm4v',
        'mov',
        'qt',
      ],
    );
    final files = picked?.files;
    if (files == null ||
        files.isEmpty ||
        files.first.path == null ||
        !mounted) {
      return;
    }
    final pickedFile = files.first;
    final attachment = await _validateAttachmentCandidateImpl(
      filePath: pickedFile.path!,
      fileName: pickedFile.name,
    );
    if (attachment == null) {
      return;
    }

    await _controller.retryAttachment(
      messageId: message.messageId,
      filePath: attachment.filePath,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
    );
  }

  Future<void> _openImageFullscreenImpl({
    required String imageUrl,
    String? fileName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SupportImagePreviewDialog(
          imageUrl: imageUrl,
          fileName: fileName,
          onSaveImage: () =>
              _saveImageToDeviceImpl(imageUrl: imageUrl, fileName: fileName),
          onShareImage: () =>
              _shareImageImpl(imageUrl: imageUrl, fileName: fileName),
          onOpenOriginal: () => _openAttachmentExternallyImpl(imageUrl),
        );
      },
    );
  }

  Future<void> _openVideoFullscreenImpl({
    required String videoUrl,
    String? fileName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SupportVideoPreviewDialog(
          videoUrl: videoUrl,
          fileName: fileName,
          onOpenOriginal: () => _openAttachmentExternallyImpl(videoUrl),
        );
      },
    );
  }

  String _formatDayLabelImpl(DateTime value) {
    final localValue = value.toLocal();
    final localNow = DateTime.now();
    if (_isSameDayImpl(localValue, localNow)) {
      return AppLocalizations.of(context).supportChatTodayLabel;
    }

    return DateFormat('MMM d').format(localValue);
  }

  bool _isSameDayImpl(DateTime left, DateTime right) {
    final localLeft = left.toLocal();
    final localRight = right.toLocal();
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }
}

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
    final galleryPermission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.photos,
    );
    if (!mounted) {
      return;
    }
    if (!galleryPermission.granted) {
      setState(() {
        _permissionState = null;
        _isInitialLoading = false;
        _assets = const [];
        _hasMore = false;
      });
      return;
    }

    final permission = await PhotoManager.requestPermissionExtend();
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

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
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
    });

    if (_recentAlbum == null) {
      return;
    }

    await _loadNextPage(reset: true);
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
    final fetched = await _recentAlbum!.getAssetListPaged(
      page: currentPage,
      size: _supportAttachmentRecentAssetCount,
    );
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
    });
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
                  axisAlignment: -1,
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
                    return Image.memory(bytes, fit: BoxFit.cover);
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
