import 'package:flutter/material.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

part 'random_template_sheet_components.part.dart';
part 'random_template_sheet_content.part.dart';

typedef RandomTemplateFinder =
    Future<TemplateItem?> Function(RandomTemplateSettings settings);

Future<TemplateItem?> showRandomTemplateSettingsSheet(
  BuildContext context, {
  required TemplateType? initialType,
  required String? initialCategory,
  required List<String> categories,
  required RandomTemplateFinder onFind,
}) {
  return showPetMagicModalBottomSheet<TemplateItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.78,
    ),
    builder: (sheetContext, bottomInset) => _RandomTemplateSettingsSheet(
      initialType: initialType,
      initialCategory: initialCategory,
      categories: categories,
      bottomInset: bottomInset,
      onFind: onFind,
    ),
  );
}

class RandomTemplateSettings {
  const RandomTemplateSettings({
    required this.type,
    required this.category,
    required this.access,
  });

  final TemplateType? type;
  final String? category;
  final TemplateRandomAccess access;
}

enum _RandomTemplateSheetStatus { idle, loading, empty, error }

class _RandomTemplateSettingsSheet extends StatefulWidget {
  const _RandomTemplateSettingsSheet({
    required this.initialType,
    required this.initialCategory,
    required this.categories,
    required this.bottomInset,
    required this.onFind,
  });

  final TemplateType? initialType;
  final String? initialCategory;
  final List<String> categories;
  final double bottomInset;
  final RandomTemplateFinder onFind;

  @override
  State<_RandomTemplateSettingsSheet> createState() =>
      _RandomTemplateSettingsSheetState();
}

class _RandomTemplateSettingsSheetState
    extends State<_RandomTemplateSettingsSheet> {
  late TemplateType? _type = widget.initialType;
  late String? _category = _normalizeRandomCategory(widget.initialCategory);
  TemplateRandomAccess _access = TemplateRandomAccess.available;
  _RandomTemplateSheetStatus _status = _RandomTemplateSheetStatus.idle;

  List<String> get _categories {
    final seen = <String>{};
    final result = <String>[];
    for (final category in widget.categories) {
      final normalized = _normalizeRandomCategory(category);
      if (normalized == null) {
        continue;
      }
      if (seen.add(normalized.toLowerCase())) {
        result.add(normalized);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return _RandomTemplateSheetContent(
      bottomInset: widget.bottomInset,
      categories: _categories,
      type: _type,
      category: _category,
      access: _access,
      status: _status,
      onSelectType: (type) => setState(() => _type = type),
      onSelectCategory: (category) => setState(() => _category = category),
      onSelectAccess: (access) => setState(() => _access = access),
      onResetFilters: _resetFilters,
      onFindRandomTemplate: _findRandomTemplate,
    );
  }

  Future<void> _findRandomTemplate() async {
    if (_status == _RandomTemplateSheetStatus.loading) {
      return;
    }

    setState(() => _status = _RandomTemplateSheetStatus.loading);
    try {
      final template = await widget.onFind(
        RandomTemplateSettings(
          type: _type,
          category: _category,
          access: _access,
        ),
      );
      if (!mounted) {
        return;
      }
      if (template == null) {
        setState(() => _status = _RandomTemplateSheetStatus.empty);
        return;
      }
      Navigator.of(context).pop(template);
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'templates',
        operation: 'pickRandomTemplate',
        message: 'Failed to pick random template',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() => _status = _RandomTemplateSheetStatus.error);
    }
  }

  void _resetFilters() {
    setState(() {
      _type = null;
      _category = null;
      _access = TemplateRandomAccess.available;
      _status = _RandomTemplateSheetStatus.idle;
    });
  }
}

String? _normalizeRandomCategory(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

TemplateRandomMode randomModeForTemplateType(TemplateType? type) {
  return switch (type) {
    null => TemplateRandomMode.any,
    TemplateType.image => TemplateRandomMode.image,
    TemplateType.video => TemplateRandomMode.video,
  };
}
