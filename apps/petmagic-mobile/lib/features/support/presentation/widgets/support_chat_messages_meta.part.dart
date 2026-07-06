part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _MessageMetaFooter extends StatelessWidget {
  const _MessageMetaFooter({
    required this.timeLabel,
    required this.showDeliveryStatus,
    required this.message,
    required this.timeColor,
    this.compact = false,
  });

  final String timeLabel;
  final bool showDeliveryStatus;
  final SupportChatMessage message;
  final Color timeColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeLabel,
          style: TextStyle(
            color: timeColor,
            fontSize: compact ? 10.5 : 11.2,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        if (showDeliveryStatus) ...[
          const SizedBox(width: 4),
          _MessageDeliveryStatusIcon(
            message: message,
            compact: compact,
            tintColor: timeColor,
          ),
        ],
      ],
    );

    if (!compact) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: content,
    );
  }
}

class _MediaWithOverlayMeta extends StatelessWidget {
  const _MediaWithOverlayMeta({
    required this.child,
    required this.meta,
    required this.borderRadius,
  });

  final Widget child;
  final Widget meta;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          child,
          Positioned(right: 6, bottom: 6, child: meta),
        ],
      ),
    );
  }
}

class _MessageDeliveryStatusIcon extends StatelessWidget {
  const _MessageDeliveryStatusIcon({
    required this.message,
    this.compact = false,
    this.tintColor,
  });

  final SupportChatMessage message;
  final bool compact;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final iconColor =
        tintColor ?? (compact ? Colors.white.withValues(alpha: 0.88) : null);
    final composerTone = _supportComposerSendGreen(context);
    final iconSize = compact ? 12.2 : 13.0;
    Widget statusIcon;
    if (message.isAttachmentUploading) {
      statusIcon = SizedBox(
        key: const ValueKey<String>('uploading'),
        width: compact ? 11.5 : 12,
        height: compact ? 11.5 : 12,
        child: CircularProgressIndicator(
          strokeWidth: compact ? 1.6 : 1.8,
          valueColor: AlwaysStoppedAnimation<Color>(
            iconColor ?? Colors.white70,
          ),
        ),
      );
    } else if (message.isAttachmentFailed) {
      statusIcon = Icon(
        key: const ValueKey<String>('failed'),
        Icons.error_outline_rounded,
        size: compact ? 12 : 12.5,
        color: colors.danger,
      );
    } else if (message.isRead) {
      statusIcon = Icon(
        key: const ValueKey<String>('read'),
        Icons.done_all_rounded,
        size: iconSize,
        color: iconColor ?? composerTone,
      );
    } else {
      statusIcon = Icon(
        key: const ValueKey<String>('sent'),
        Icons.check_rounded,
        size: iconSize,
        color: iconColor ?? Colors.white.withValues(alpha: 0.78),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: statusIcon,
    );
  }
}
