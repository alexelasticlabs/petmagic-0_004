part of 'template_preview_page.dart';

extension _TemplatePreviewInformationGestures on _TemplatePreviewPageState {
  Widget _buildInformationPanel(TemplateItem template, PetMagicColors colors) {
    final scaler = MediaQuery.textScalerOf(context);
    // The envelope depends on the viewport and accessibility settings, never
    // on the selected template or an asynchronously hydrated description.
    final compactWidth =
        MediaQuery.sizeOf(context).width / scaler.scale(1) < 360;
    final summaryHeight = 20 + scaler.scale(compactWidth ? 156 : 136);
    final hasRail = _items.length > 1 || _isLoadingMore || _paginationFailed;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (summaryHeight + (hasRail ? 86 : 0)).clamp(
          0.0,
          constraints.maxHeight,
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                if (hasRail) ...[
                  _buildThumbnailRail(colors),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: _startInformationDrag,
                    onHorizontalDragUpdate: (details) {
                      if (_informationDragDistance != null) {
                        _informationDragDistance =
                            _informationDragDistance! + details.delta.dx;
                      }
                    },
                    onHorizontalDragEnd: _endInformationDrag,
                    onHorizontalDragCancel: () =>
                        _informationDragDistance = null,
                    child: SingleChildScrollView(
                      key: const ValueKey('template-preview-information'),
                      controller: _informationController,
                      child: _TemplatePreviewSummary(
                        template: template,
                        reduceMotion: _reduceMotion,
                        direction: _selectionDirection,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startInformationDrag(DragStartDetails details) {
    if (_isInteractionLocked ||
        _items.length < 2 ||
        !_pageController.hasClients) {
      return;
    }
    // Do not inject a second drag activity into PageView's ScrollPosition.
    // A tap, cancelled gesture or vertical description scroll must never lock CTA.
    _informationDragDistance = 0;
  }

  void _endInformationDrag(DragEndDetails details) {
    final distance = _informationDragDistance;
    _informationDragDistance = null;
    if (distance == null || _isInteractionLocked) return;
    final velocity = details.primaryVelocity ?? 0;
    if (distance.abs() < 48 && velocity.abs() < 400) return;
    final delta = velocity.abs() >= 400 ? velocity : distance;
    final target = (_selectedIndex + (delta < 0 ? 1 : -1)).clamp(
      0,
      _items.length - 1,
    );
    _selectThumbnail(target);
  }
}

class _TemplatePreviewDescription extends StatefulWidget {
  const _TemplatePreviewDescription({
    required this.description,
    required this.isVideo,
    required this.reduceMotion,
    super.key,
  });

  final String description;
  final bool isVideo;
  final bool reduceMotion;

  @override
  State<_TemplatePreviewDescription> createState() =>
      _TemplatePreviewDescriptionState();
}

class _TemplatePreviewDescriptionState
    extends State<_TemplatePreviewDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final description = widget.description.trim().isNotEmpty
        ? widget.description.trim()
        : widget.isVideo
        ? text.templateDetailFallbackDescriptionVideo
        : text.templateDetailFallbackDescriptionImage;
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: Colors.white.withValues(alpha: 0.82),
      height: 1.35,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: description, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth);
        final canExpand = painter.didExceedMaxLines;
        painter.dispose();
        return GestureDetector(
          onTap: canExpand
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(
                context,
              ).scale(style.fontSize! * 2.7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedSize(
                    duration: widget.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Text(
                      description,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
                ),
                if (canExpand)
                  IconButton(
                    key: const ValueKey('template-preview-description-toggle'),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    color: Colors.white70,
                    tooltip: _expanded
                        ? text.templatePreviewDescriptionLess
                        : text.templatePreviewDescriptionMore,
                    icon: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: widget.reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      child: const Icon(Icons.expand_more_rounded, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
