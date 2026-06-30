import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

class AndroidLoopbackBackendHint extends StatelessWidget {
  const AndroidLoopbackBackendHint({
    required this.config,
    this.compact = false,
    super.key,
  });

  final AndroidLoopbackBackendHintConfig config;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 10 : 12,
        compact ? 12 : 14,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(
          color: colors.gold.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.usb_rounded, color: colors.gold, size: compact ? 18 : 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.localBackendAndroidHintTitle,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: compact ? 12.5 : 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text.localBackendAndroidHintMessage(
                    config.baseUrl,
                    config.port.toString(),
                  ),
                  style: TextStyle(
                    color: colors.textSoft,
                    fontSize: compact ? 11.5 : 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
