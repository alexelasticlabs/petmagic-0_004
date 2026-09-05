import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_entitlement_provider.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';

part 'template_preview_viewer.part.dart';
part 'template_preview_viewer_actions.part.dart';
part 'template_preview_viewer_pagination.part.dart';
part 'template_preview_viewer_widgets.part.dart';

enum TemplatePreviewSource {
  catalog,
  discovery,
  featured,
  random,
  deepLink;

  String get analyticsValue => switch (this) {
    TemplatePreviewSource.catalog => 'catalog',
    TemplatePreviewSource.discovery => 'discovery',
    TemplatePreviewSource.featured => 'featured',
    TemplatePreviewSource.random => 'random',
    TemplatePreviewSource.deepLink => 'deep_link',
  };
}

class TemplatePreviewPageBatch {
  const TemplatePreviewPageBatch({required this.items, required this.hasMore});

  final List<TemplateItem> items;
  final bool hasMore;
}

typedef TemplatePreviewPageLoader = Future<TemplatePreviewPageBatch> Function();

class TemplatePreviewSession {
  factory TemplatePreviewSession({
    required List<TemplateItem> items,
    required int initialIndex,
    TemplatePreviewSource source = TemplatePreviewSource.catalog,
    TemplatePreviewPageLoader? loadMore,
    bool initialDetailResolved = false,
  }) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'Must not be empty.');
    }
    if (initialIndex < 0 || initialIndex >= items.length) {
      throw RangeError.index(initialIndex, items, 'initialIndex');
    }

    return TemplatePreviewSession.fromSelection(
      items: items,
      selectedTemplate: items[initialIndex],
      source: source,
      loadMore: loadMore,
      initialDetailResolved: initialDetailResolved,
    );
  }

  factory TemplatePreviewSession.fromSelection({
    required List<TemplateItem> items,
    required TemplateItem selectedTemplate,
    TemplatePreviewSource source = TemplatePreviewSource.catalog,
    TemplatePreviewPageLoader? loadMore,
    bool initialDetailResolved = false,
  }) {
    final selectedId = selectedTemplate.templateId.trim();
    final normalized = <TemplateItem>[];
    final indexesById = <String, int>{};
    var selectedIndex = -1;

    for (final item in items) {
      final id = item.templateId.trim();
      final existingIndex = indexesById[id];
      if (existingIndex != null) {
        if (id == selectedId) {
          normalized[existingIndex] = selectedTemplate;
          selectedIndex = existingIndex;
        }
        continue;
      }

      indexesById[id] = normalized.length;
      normalized.add(id == selectedId ? selectedTemplate : item);
      if (id == selectedId) {
        selectedIndex = normalized.length - 1;
      }
    }

    if (selectedIndex < 0) {
      normalized.insert(0, selectedTemplate);
      selectedIndex = 0;
    }

    return TemplatePreviewSession._(
      items: List<TemplateItem>.unmodifiable(normalized),
      initialIndex: selectedIndex,
      source: source,
      loadMore: loadMore,
      initialDetailResolved: initialDetailResolved,
    );
  }

  factory TemplatePreviewSession.single(
    TemplateItem template, {
    TemplatePreviewSource source = TemplatePreviewSource.catalog,
    bool initialDetailResolved = false,
  }) {
    return TemplatePreviewSession._(
      items: List<TemplateItem>.unmodifiable([template]),
      initialIndex: 0,
      source: source,
      loadMore: null,
      initialDetailResolved: initialDetailResolved,
    );
  }

  const TemplatePreviewSession._({
    required this.items,
    required this.initialIndex,
    required this.source,
    required this.loadMore,
    required this.initialDetailResolved,
  });

  final List<TemplateItem> items;
  final int initialIndex;
  final TemplatePreviewSource source;
  final TemplatePreviewPageLoader? loadMore;
  final bool initialDetailResolved;

  TemplateItem get initialTemplate => items[initialIndex];
}

class TemplatePreviewRouteArgs {
  const TemplatePreviewRouteArgs({
    required this.template,
    required this.hasPremiumAccess,
    required this.isAuthenticated,
    this.session,
  });

  final TemplateItem template;
  final bool hasPremiumAccess;
  final bool isAuthenticated;
  final TemplatePreviewSession? session;

  TemplatePreviewSession get effectiveSession =>
      session ?? TemplatePreviewSession.single(template);
}

class TemplatePreviewResult {
  const TemplatePreviewResult({
    required this.action,
    required this.selectedTemplate,
  });

  final TemplateDetailAction action;
  final TemplateItem selectedTemplate;
}

class TemplatePreviewPage extends ConsumerStatefulWidget {
  const TemplatePreviewPage({
    required this.template,
    this.hasPremiumAccess = false,
    this.isAuthenticated = false,
    this.session,
    super.key,
  });

  static const routePath = '/templates/preview';

  final TemplateItem template;
  final bool hasPremiumAccess;
  final bool isAuthenticated;
  final TemplatePreviewSession? session;

  @override
  ConsumerState<TemplatePreviewPage> createState() =>
      _TemplatePreviewPageState();
}
