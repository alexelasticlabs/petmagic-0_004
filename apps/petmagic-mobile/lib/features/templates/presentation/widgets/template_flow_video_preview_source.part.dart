part of 'template_flow_sheets.dart';

extension _NetworkVideoPreviewSource on _NetworkVideoPreviewState {
  Future<void> _cancelUpgrade() async {
    _upgradeVersion++;
    _upgradeInFlight = false;
    _cancelSlotWait(detailOnly: true);
    final lease = _upgradeLease;
    _upgradeLease = null;
    await lease?.dispose(pauseFirst: true);
  }

  bool _isCurrentUpgrade(int token, VideoPlayerController previous) =>
      mounted &&
      token == _upgradeVersion &&
      _isAppResumed &&
      widget.isActive &&
      widget.allowDetailUpgrade &&
      _isVisibleEnoughToLoad &&
      identical(previous, _controller);

  Future<void> _upgradeToDetail() async {
    final previous = _controller;
    if (_upgradeInFlight ||
        !widget.allowDetailUpgrade ||
        previous == null ||
        !previous.value.isInitialized ||
        _sourceUrl == widget.url ||
        _rejectedSourceUrls.contains(widget.url) ||
        !_isAppResumed ||
        !widget.isActive ||
        !_isVisibleEnoughToLoad) {
      return;
    }
    final detailUrl = widget.url;
    final mediaVersion = widget.mediaVersion;
    final safeUri = parseSafeGenerationMediaUri(detailUrl);
    if (safeUri == null) return;
    final token = ++_upgradeVersion;
    _upgradeInFlight = true;
    _TemplateVideoPreviewControllerLease? lease;
    VideoPlayerController? next;
    var nativeDecodeFailed = false;
    try {
      // Give directional fast prefetch priority during rapid swiping.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!_isCurrentUpgrade(token, previous)) return;
      next = await _createVideoController(detailUrl, safeUri);
      if (!_isCurrentUpgrade(token, previous)) return;
      lease = _TemplateVideoPreviewControllerLease.tryAcquire(
        useSharedPreviewCache: widget.useSharedPreviewCache,
      );
      if (lease == null) {
        _waitForSlot(detail: true);
        return;
      }
      lease.attach(next);
      _upgradeLease = lease;
      await next.setVolume(0);
      if (!_isCurrentUpgrade(token, previous)) return;
      await next.setLooping(true);
      if (!_isCurrentUpgrade(token, previous)) return;
      try {
        await next.initialize();
      } catch (_) {
        nativeDecodeFailed =
            widget.useSharedPreviewCache &&
            next.dataSourceType == DataSourceType.file &&
            next.value.hasError;
        rethrow;
      }
      if (!_isCurrentUpgrade(token, previous)) return;
      final position = previous.value.position;
      await next.seekTo(
        position < next.value.duration ? position : Duration.zero,
      );
      if (!_isCurrentUpgrade(token, previous)) return;
      // Never let two decoders become audible during the handover.
      _handoverController = previous;
      _handoverVersion = token;
      _playbackSyncVersion++;
      await previous.setVolume(0);
      await previous.pause();
      if (!_isCurrentUpgrade(token, previous)) return;
      final previousLease = _controllerLease;
      _controller = next;
      _controllerLease = lease;
      _sourceUrl = detailUrl;
      widget.playbackRegistry?._publish(
        widget.playbackIdentity,
        widget.mediaVersion,
        next,
      );
      _handoverController = null;
      _upgradeLease = null;
      lease = null;
      next = null;
      _refreshVideoPreview();
      await _syncPlaybackState();
      await previousLease?.dispose(pauseFirst: true);
    } catch (error, stackTrace) {
      if (nativeDecodeFailed && _isCurrentUpgrade(token, previous)) {
        await _rejectCachedSource(detailUrl, mediaVersion: mediaVersion);
      }
      AppLogger.warn(
        feature: 'Templates.FlowMediaPreview',
        operation: 'upgrade_video_preview',
        message:
            'Keeping the playable feed preview after detail upgrade failed.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (token == _handoverVersion &&
          identical(_handoverController, previous)) {
        _handoverController = null;
      }
      if (lease != null) {
        if (identical(_upgradeLease, lease)) _upgradeLease = null;
        await lease.dispose(pauseFirst: true);
      } else if (next != null) {
        await _disposeUnleasedController(next);
      }
      if (mounted) {
        if (token == _upgradeVersion) _upgradeInFlight = false;
        await _syncPlaybackState();
        if (_waitingForDetailSlot) _resumeAfterSlotRelease();
      }
    }
  }
}
