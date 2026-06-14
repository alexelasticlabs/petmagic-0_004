import 'dart:math';

import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

List<TemplateItem> filterRandomTemplateCandidates(
  Iterable<TemplateItem> templates, {
  required TemplateRandomMode mode,
  required bool hasPremiumAccess,
}) {
  return templates
      .where(
        (template) => _isRandomTemplateCandidate(
          template,
          mode: mode,
          hasPremiumAccess: hasPremiumAccess,
        ),
      )
      .toList(growable: false);
}

TemplateItem? selectRandomTemplate(
  Iterable<TemplateItem> templates, {
  required TemplateRandomMode mode,
  required bool hasPremiumAccess,
  Random? random,
}) {
  final candidates = filterRandomTemplateCandidates(
    templates,
    mode: mode,
    hasPremiumAccess: hasPremiumAccess,
  );
  if (candidates.isEmpty) {
    return null;
  }

  final randomSource = random ?? Random();
  return candidates[randomSource.nextInt(candidates.length)];
}

bool _isRandomTemplateCandidate(
  TemplateItem template, {
  required TemplateRandomMode mode,
  required bool hasPremiumAccess,
}) {
  if (template.templateId.trim().isEmpty) {
    return false;
  }

  if (!hasPremiumAccess && template.isPremium) {
    return false;
  }

  if (!_matchesMode(template, mode)) {
    return false;
  }

  return _hasValidMediaUrl(template.thumbnailUrl) ||
      _hasValidMediaUrl(template.previewAsset?.url);
}

bool _matchesMode(TemplateItem template, TemplateRandomMode mode) {
  return switch (mode) {
    TemplateRandomMode.any => true,
    TemplateRandomMode.image => template.templateType == TemplateType.image,
    TemplateRandomMode.video => template.templateType == TemplateType.video,
  };
}

bool _hasValidMediaUrl(String? rawUrl) {
  final normalized = rawUrl?.trim().replaceAll('\\', '/');
  if (normalized == null || normalized.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(Uri.encodeFull(normalized));
  return uri != null &&
      (uri.hasScheme || normalized.startsWith('/') || uri.path.isNotEmpty);
}
