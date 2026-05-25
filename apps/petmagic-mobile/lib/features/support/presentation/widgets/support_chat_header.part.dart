part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportHeader extends StatelessWidget {
  const _SupportHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textStrong,
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surfaceStrong,
                  colors.accent.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            ),
            child: Icon(Icons.pets_rounded, size: 20, color: colors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _supportSecondaryGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportSecurityCard extends StatelessWidget {
  const _SupportSecurityCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ProfileGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.accent.withValues(alpha: 0.24),
                  colors.accent.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Icon(Icons.shield_rounded, color: colors.accent, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: colors.border.withValues(alpha: 0.9),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: colors.border.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
