import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';

class NetworkStatusBanner extends ConsumerWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(networkStatusControllerProvider);
    final phase = status.bannerPhase;
    if (phase == NetworkBannerPhase.hidden) {
      return const SizedBox.shrink();
    }

    final text = AppLocalizations.of(context);
    final isOffline = phase == NetworkBannerPhase.offline;
    final title = isOffline
        ? text.globalOfflineBannerTitle
        : text.globalOnlineRestoredBannerTitle;
    final message = isOffline
        ? text.globalOfflineBannerMessage
        : text.globalOnlineRestoredBannerMessage;
    final icon = isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded;
    final colors = context.petMagicColors;
    final accent = isOffline ? colors.danger : colors.accent;
    final palette = _NetworkBannerPalette.from(colors, accent);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: palette.base.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border.withValues(alpha: 0.82)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.24),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: palette.iconBg.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: palette.iconFg, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
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

class _NetworkBannerPalette {
  const _NetworkBannerPalette({
    required this.base,
    required this.border,
    required this.iconBg,
    required this.iconFg,
  });

  final Color base;
  final Color border;
  final Color iconBg;
  final Color iconFg;

  factory _NetworkBannerPalette.from(PetMagicColors colors, Color accent) {
    return _NetworkBannerPalette(
      base: Color.lerp(colors.surface, accent, 0.10) ?? colors.surface,
      border: accent,
      iconBg:
          Color.lerp(colors.surfaceStrong, accent, 0.18) ??
          colors.surfaceStrong,
      iconFg: accent,
    );
  }
}
