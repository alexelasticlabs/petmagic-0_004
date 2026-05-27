import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

class SupportAssistantScenario {
  const SupportAssistantScenario({
    required this.key,
    required this.icon,
    required this.topicLabel,
    required this.recommendation,
  });

  final String key;
  final IconData icon;
  final String topicLabel;
  final String recommendation;

  bool get isGenerationTooLong => key == 'GenerationTooLong';
}

SupportAssistantScenario buildSupportAssistantScenario(
  String? rawKey,
  AppLocalizations text,
) {
  final key = normalizeSupportScenarioKey(rawKey);

  return switch (key) {
    'GenerationIssue' => SupportAssistantScenario(
      key: key,
      icon: Icons.auto_awesome_rounded,
      topicLabel: text.supportHomeTopicGenerationIssue,
      recommendation: text.supportAssistantRecommendationGeneration,
    ),
    'GenerationTooLong' => SupportAssistantScenario(
      key: key,
      icon: Icons.timer_outlined,
      topicLabel: text.supportHomeTopicGenerationTooLong,
      recommendation: text.supportAssistantRecommendationGenerationTooLong,
    ),
    'TokensNotArrived' => SupportAssistantScenario(
      key: key,
      icon: Icons.token_outlined,
      topicLabel: text.supportHomeTopicTokensNotArrived,
      recommendation: text.supportAssistantRecommendationTokensNotArrived,
    ),
    'PremiumIssue' => SupportAssistantScenario(
      key: key,
      icon: Icons.workspace_premium_rounded,
      topicLabel: text.supportHomeTopicPremiumIssue,
      recommendation: text.supportAssistantRecommendationPremiumIssue,
    ),
    'PaymentRefund' => SupportAssistantScenario(
      key: key,
      icon: Icons.credit_card_rounded,
      topicLabel: text.supportHomeTopicPaymentRefund,
      recommendation: text.supportAssistantRecommendationPaymentRefund,
    ),
    _ => SupportAssistantScenario(
      key: 'Other',
      icon: Icons.help_outline_rounded,
      topicLabel: text.supportHomeTopicOther,
      recommendation: text.supportAssistantRecommendationOther,
    ),
  };
}

String normalizeSupportScenarioKey(String? key) {
  return switch (key) {
    'GenerationIssue' => 'GenerationIssue',
    'GenerationTooLong' => 'GenerationTooLong',
    'TokensNotArrived' => 'TokensNotArrived',
    'PremiumIssue' => 'PremiumIssue',
    'PaymentRefund' => 'PaymentRefund',
    'Other' => 'Other',
    _ => 'Other',
  };
}
