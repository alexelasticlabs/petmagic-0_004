part of 'template_preview_page.dart';

extension _TemplatePreviewRail on _TemplatePreviewPageState {
  Widget _buildThumbnailRail(PetMagicColors colors) {
    return SizedBox(
      height: 78,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final edgePadding =
              ((constraints.maxWidth -
                          _TemplatePreviewPageState._thumbnailExtent) /
                      2)
                  .clamp(4.0, double.infinity)
                  .toDouble();
          return ListView.separated(
            key: const ValueKey('template-preview-thumbnail-rail'),
            controller: _thumbnailController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: edgePadding),
            itemCount:
                _items.length + (_isLoadingMore || _paginationFailed ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(
              width: _TemplatePreviewPageState._thumbnailSpacing,
            ),
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return SizedBox(
                  width: _TemplatePreviewPageState._thumbnailExtent,
                  child: _TemplatePreviewPaginationStatus(
                    isLoading: _isLoadingMore,
                    onRetry: _retryPagination,
                  ),
                );
              }
              final template = _items[index];
              final selected = index == _selectedIndex;
              final text = AppLocalizations.of(context);
              return SizedBox(
                width: _TemplatePreviewPageState._thumbnailExtent,
                child: Semantics(
                  button: true,
                  selected: selected,
                  enabled: !_isInteractionLocked,
                  label: template.title,
                  hint: template.isVideo ? text.videoLabel : text.imageLabel,
                  value: '${index + 1} / ${_items.length}',
                  onTap: _isInteractionLocked
                      ? null
                      : () => _selectThumbnail(index),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      key: ValueKey(
                        'template-preview-thumbnail:${template.templateId}',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: _isInteractionLocked
                          ? null
                          : () => _selectThumbnail(index),
                      child: AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          final emphasis = _thumbnailEmphasis(index);
                          final accent = template.isPremium
                              ? colors.gold
                              : colors.accent;
                          final page = _pageController.hasClients
                              ? _pageController.page ??
                                    _selectedIndex.toDouble()
                              : _selectedIndex.toDouble();
                          final tilt = _reduceMotion
                              ? 0.0
                              : (index - page).clamp(-1.0, 1.0) * 0.045;
                          final borderColor = Color.lerp(
                            Colors.white.withValues(alpha: 0.28),
                            accent,
                            emphasis,
                          )!;
                          return Transform.translate(
                            offset: Offset(
                              0,
                              _reduceMotion ? 0 : 2 - 5 * emphasis,
                            ),
                            child: Transform.rotate(
                              angle: tilt,
                              child: Transform.scale(
                                scale: 0.84 + (0.16 * emphasis),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1 + (1.6 * emphasis),
                                    ),
                                    boxShadow: emphasis <= 0.01
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: accent.withValues(
                                                alpha: 0.38 * emphasis,
                                              ),
                                              blurRadius: 6 + (14 * emphasis),
                                              offset: Offset(
                                                0,
                                                2 + (3 * emphasis),
                                              ),
                                            ),
                                          ],
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: _TemplatePreviewThumbnail(
                            template: template,
                            isActive: index == _mediaIndex && !_isDetailsOpen,
                            autoplay: !_reduceMotion,
                            playbackRegistry: _playbackRegistry,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
