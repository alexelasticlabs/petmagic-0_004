part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

extension _SupportAttachmentPickerView on _SupportAttachmentPickerSheetState {
  Widget _buildContent(BuildContext context) {
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
