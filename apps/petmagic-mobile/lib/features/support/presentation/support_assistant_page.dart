import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'support_assistant_scenarios.dart';
import 'support_ticket_form_page.dart';

class SupportAssistantPage extends ConsumerWidget {
  const SupportAssistantPage({required this.scenario, super.key});

  static const routePath = '/profile/support/assistant';
  static const scenarioQueryParam = 'scenario';

  final String scenario;

  static String location(String scenario) {
    final normalizedScenario = normalizeSupportScenarioQuery(scenario);
    if (normalizedScenario == null) {
      return routePath;
    }

    return '$routePath?$scenarioQueryParam=${Uri.encodeQueryComponent(normalizedScenario)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final scenarioData = buildSupportAssistantScenario(scenario, text);

    if (!isAuthenticated) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: SupportAssistantPage.location(scenario),
              ),
            ),
          ),
        ),
      );
    }

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(text.supportAssistantTitle),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    scenarioData.topicLabel,
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ProfileGlassCard(
                  child: Text(
                    scenarioData.recommendation,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.push(
                        SupportTicketFormPage.location(scenarioData.key),
                      ),
                      icon: const Icon(Icons.headset_mic_rounded, size: 18),
                      label: Text(text.supportAssistantCreateTicketAction),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSoft,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        scenarioData.isGenerationTooLong
                            ? text.supportAssistantCheckLaterAction
                            : text.supportAssistantThisHelpedAction,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
