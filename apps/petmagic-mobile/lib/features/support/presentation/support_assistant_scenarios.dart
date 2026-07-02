import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

const int maxSupportScenarioQueryLength = 64;
final RegExp _supportScenarioControlPattern = RegExp(r'[\x00-\x1F\x7F]');

class SupportAssistantScenario {
  const SupportAssistantScenario({
    required this.key,
    required this.icon,
    this.isPremium = false,
    required this.topicLabel,
    required this.recommendation,
  });

  final String key;
  final IconData icon;
  final bool isPremium;
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
      icon: Icons.star_rounded,
      isPremium: true,
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

String? normalizeSupportScenarioQuery(String? value) {
  final normalized = value?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      _supportScenarioControlPattern.hasMatch(normalized)) {
    return null;
  }

  return normalized.length <= maxSupportScenarioQueryLength
      ? normalized
      : normalized.substring(0, maxSupportScenarioQueryLength);
}
