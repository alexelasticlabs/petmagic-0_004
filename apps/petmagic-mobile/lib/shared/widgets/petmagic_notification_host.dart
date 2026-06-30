import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_types.dart';

class PetMagicNotificationHost extends ConsumerStatefulWidget {
  const PetMagicNotificationHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PetMagicNotificationHost> createState() =>
      _PetMagicNotificationHostState();
}

class _PetMagicNotificationHostState
    extends ConsumerState<PetMagicNotificationHost> {
  final PetMagicNotificationCenter _center =
      PetMagicNotificationCenter.instance;

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _center.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _center.removeListener(_handleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNetworkBanner = ref.watch(
      networkStatusControllerProvider.select(
        (state) => state.bannerPhase != NetworkBannerPhase.hidden,
      ),
    );
    final notification = _center.current;
    if (notification == null) {
      return widget.child;
    }

    final colors = context.petMagicColors;
    final reduceEffects = PerformanceGuard.shouldDisableSharedRouteAnimations(
      context,
    );
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  hasNetworkBanner ? 78 : 10,
                  14,
                  0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AnimatedSwitcher(
                    duration: reduceEffects
                        ? const Duration(milliseconds: 120)
                        : const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      if (reduceEffects) {
                        return FadeTransition(opacity: animation, child: child);
                      }
                      final slide = Tween<Offset>(
                        begin: const Offset(0, -0.08),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: _NotificationBanner(
                      key: ValueKey<String>(notification.id),
                      notification: notification,
                      colors: colors,
                      reduceEffects: reduceEffects,
                      onClose: () => _center.dismissCurrent(),
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

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required super.key,
    required this.notification,
    required this.colors,
    required this.reduceEffects,
    required this.onClose,
  });

  final PetMagicNotification notification;
  final PetMagicColors colors;
  final bool reduceEffects;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final toneColors = switch (notification.tone) {
      PetMagicToastTone.success => (
        base: const Color(0xFF0F2C22),
        border: const Color(0xFF2B8C67),
        accent: const Color(0xFF27D38A),
        iconBg: const Color(0xFF163F31),
      ),
      PetMagicToastTone.warning => (
        base: const Color(0xFF30201F),
        border: const Color(0xFFAD5762),
        accent: const Color(0xFFFF7A8C),
        iconBg: const Color(0xFF4A2A2F),
      ),
      PetMagicToastTone.info => (
        base: const Color(0xFF162636),
        border: const Color(0xFF3A6FB2),
        accent: const Color(0xFF6FA8FF),
        iconBg: const Color(0xFF1C3550),
      ),
    };

    final icon = switch (notification.tone) {
      PetMagicToastTone.success => Icons.check_circle_rounded,
      PetMagicToastTone.warning => Icons.error_rounded,
      PetMagicToastTone.info => Icons.info_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: toneColors.base.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: toneColors.border.withValues(alpha: 0.72)),
          boxShadow: reduceEffects
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              if (!reduceEffects)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            toneColors.accent.withValues(alpha: 0.10),
                            Colors.transparent,
                            colors.surface.withValues(alpha: 0.03),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: toneColors.iconBg.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: toneColors.accent.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Icon(icon, color: toneColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (notification.title != null) ...[
                              Text(
                                notification.title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              notification.message,
                              maxLines: notification.title == null ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            if (notification.action != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () async {
                                    await notification.action!.onPressed();
                                    onClose();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: toneColors.accent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    notification.action!.label,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
