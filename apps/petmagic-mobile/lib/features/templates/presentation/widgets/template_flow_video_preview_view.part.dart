part of 'template_flow_sheets.dart';

extension _NetworkVideoPreviewView on _NetworkVideoPreviewState {
  Widget _buildVideoPreview(BuildContext context) {
    final controller = _controller;
    final text = AppLocalizations.of(context);
    final posterUrl = widget.posterUrl;
    final hasPoster = posterUrl != null;
    final isInitialized =
        _canPrepare && (controller?.value.isInitialized ?? false);
    final poster =
        widget.placeholder ??
        (hasPoster
            ? TemplatePreviewImage(
                imageUrl: posterUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                cacheWidth: widget.posterCacheWidth,
                mediaVersion: widget.mediaVersion,
                placeholder: _EmptyMediaBox(
                  label: text.templateFlowLoadingPreview,
                ),
                errorBuilder: (_) => _TemplatePreviewPlaceholder(
                  isVideo: true,
                  title: _templatePreviewMissingTitle(text),
                  subtitle: _templatePreviewMissingSubtitle(
                    text,
                    isVideo: true,
                  ),
                ),
              )
            : _EmptyMediaBox(label: text.templateFlowLoadingVideo));

    final child = Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: isInitialized, child: poster),
        if (_failedToLoad && !hasPoster && widget.placeholder == null)
          _TemplatePreviewPlaceholder(
            isVideo: true,
            title: _templatePreviewMissingTitle(text),
            subtitle: _templatePreviewMissingSubtitle(text, isVideo: true),
          ),
        if (widget.isActive && !_failedToLoad && !isInitialized)
          Center(
            child: Semantics(
              label: text.templateFlowLoadingVideo,
              child: SizedBox.square(
                dimension: widget.placeholder == null ? 28 : 16,
                child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          ),
        if (widget.isActive && _failedToLoad && widget.placeholder == null)
          Center(
            child: IconButton.filledTonal(
              tooltip: text.retryAction,
              onPressed: _retryInitialization,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        if (isInitialized) ...[
          TweenAnimationBuilder<double>(
            key: ValueKey(
              'template-preview-video-reveal:${widget.playbackIdentity}',
            ),
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          if (widget.isActive &&
              widget.showPlaybackControl &&
              widget.immersiveControls)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.42),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _playbackButton(controller, text),
                        if (widget.onMutedChanged != null) ...[
                          Container(
                            width: 1,
                            height: 18,
                            color: Colors.white24,
                          ),
                          IconButton(
                            key: const ValueKey('template-preview-mute'),
                            color: Colors.white,
                            tooltip: widget.muted
                                ? text.mediaUnmuteAction
                                : text.mediaMuteAction,
                            onPressed: () =>
                                widget.onMutedChanged!(!widget.muted),
                            icon: _animatedControlIcon(
                              widget.muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (widget.isActive && widget.showPlaybackControl)
            Align(
              alignment: widget.playbackControlAlignment,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _playbackButton(controller, text),
              ),
            ),
        ],
      ],
    );

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: child,
    );
  }

  Widget _playbackButton(
    VideoPlayerController controller,
    AppLocalizations text,
  ) {
    return IconButton(
      key: const ValueKey('template-preview-playback'),
      color: Colors.white,
      tooltip: controller.value.isPlaying
          ? text.mediaPauseAction
          : text.mediaPlayAction,
      onPressed: () {
        _manualPaused = controller.value.isPlaying;
        _manualStarted = !_manualPaused;
        unawaited(_syncPlaybackState());
      },
      icon: _animatedControlIcon(
        controller.value.isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
      ),
    );
  }

  Widget _animatedControlIcon(IconData icon) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Icon(icon, key: ValueKey(icon), size: 21),
    );
  }
}
