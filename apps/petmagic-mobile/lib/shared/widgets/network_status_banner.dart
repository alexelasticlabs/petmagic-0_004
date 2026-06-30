import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
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
    final palette = isOffline
        ? (
            base: const Color(0xFF3A1E22),
            border: const Color(0xFFF87171),
            iconBg: const Color(0xFF52262C),
            iconFg: const Color(0xFFFF9AA2),
          )
        : (
            base: const Color(0xFF112A21),
            border: const Color(0xFF34D399),
            iconBg: const Color(0xFF17392D),
            iconFg: const Color(0xFF6EE7B7),
          );

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: palette.base.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border.withValues(alpha: 0.82)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
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
                        color: Colors.white.withValues(alpha: 0.96),
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
                        color: Colors.white.withValues(alpha: 0.88),
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
