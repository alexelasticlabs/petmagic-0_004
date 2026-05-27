import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'support_assistant_scenarios.dart';
import 'support_assistant_page.dart';

class SupportHomePage extends StatelessWidget {
  const SupportHomePage({super.key});

  static const routePath = '/profile/support';

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    final topics = _buildTopics(text);

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(text.supportHomeTitle),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                text.supportHomeSubtitle,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              ...topics.map((topic) => _TopicCard(topic: topic)),
            ],
          ),
        ),
      ),
    );
  }

  List<_SupportTopic> _buildTopics(AppLocalizations text) {
    const keys = <String>[
      'GenerationIssue',
      'GenerationTooLong',
      'TokensNotArrived',
      'PremiumIssue',
      'PaymentRefund',
      'Other',
    ];
    return keys
        .map((key) => buildSupportAssistantScenario(key, text))
        .map(
          (scenario) => _SupportTopic(
            icon: scenario.icon,
            label: scenario.topicLabel,
            scenario: scenario.key,
          ),
        )
        .toList(growable: false);
  }
}

class _SupportTopic {
  const _SupportTopic({
    required this.icon,
    required this.label,
    required this.scenario,
  });

  final IconData icon;
  final String label;
  final String scenario;
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final _SupportTopic topic;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProfileGlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.push(
            '${SupportAssistantPage.routePath}?scenario=${Uri.encodeComponent(topic.scenario)}',
          ),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(topic.icon, color: colors.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    topic.label,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textSoft,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
