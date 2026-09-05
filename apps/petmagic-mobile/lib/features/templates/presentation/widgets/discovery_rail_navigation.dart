import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

/// Only the small scroll indicator rebuilds while the media rail moves.
class DiscoveryRailViewport extends StatefulWidget {
  const DiscoveryRailViewport({
    required this.child,
    this.showIndicator = true,
    super.key,
  });

  final Widget child;
  final bool showIndicator;

  @override
  State<DiscoveryRailViewport> createState() => _DiscoveryRailViewportState();
}

class _DiscoveryRailViewportState extends State<DiscoveryRailViewport> {
  final _position = ValueNotifier<({double fraction, double progress})>((
    fraction: 1,
    progress: 0,
  ));

  void _update(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return;
    final extent = metrics.maxScrollExtent - metrics.minScrollExtent;
    final total = extent + metrics.viewportDimension;
    _position.value = (
      fraction: total <= 0
          ? 1
          : (metrics.viewportDimension / total).clamp(0.08, 1),
      progress: extent <= 0
          ? 0
          : ((metrics.pixels - metrics.minScrollExtent) / extent).clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: (event) {
            _update(event.metrics);
            return false;
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (event) {
              _update(event.metrics);
              return false;
            },
            child: widget.child,
          ),
        ),
        if (widget.showIndicator) const SizedBox(height: 8),
        if (widget.showIndicator)
          ExcludeSemantics(
            child: SizedBox(
              height: 3,
              width: 64,
              child: ValueListenableBuilder(
                valueListenable: _position,
                builder: (context, position, _) => Opacity(
                  opacity: position.fraction >= 1 ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional(
                        position.progress * 2 - 1,
                        0,
                      ),
                      child: FractionallySizedBox(
                        widthFactor: position.fraction,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.accentInk,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
