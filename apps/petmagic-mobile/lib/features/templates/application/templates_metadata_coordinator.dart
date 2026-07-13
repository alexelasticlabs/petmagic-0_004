import 'dart:async';

import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_policy.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

/// Loads catalog metadata independently from feed pagination.
final class TemplatesMetadataCoordinator {
  const TemplatesMetadataCoordinator({
    required this.repository,
    required this.readState,
    required this.writeState,
    required this.isMounted,
    required this.isScreenVisible,
    required this.currentRequestVersion,
    required this.warmupThumbnail,
  });

  final TemplatesRepository Function() repository;
  final TemplatesState Function() readState;
  final void Function(TemplatesState state) writeState;
  final bool Function() isMounted;
  final bool Function() isScreenVisible;
  final int Function() currentRequestVersion;
  final Future<void> Function(String url) warmupThumbnail;

  bool shouldLoadTemplateOfTheDay({required bool forceRefresh}) {
    if (forceRefresh) return true;
    final state = readState();
    return state.templateOfTheDay == null &&
        state.templateOfTheDayError == null &&
        !state.isTemplateOfTheDayLoading;
  }

  Future<void> refreshCategories(int requestVersion) async {
    try {
      final categories = TemplatesFeedPolicy.normalizeCategories(
        await repository().fetchCategories(),
      );
      if (!_isCurrentRequest(requestVersion)) return;
      scheduleMicrotask(() {
        if (_isCurrentRequest(requestVersion)) {
          writeState(readState().copyWith(categories: categories));
        }
      });
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Controller',
        operation: 'refresh_categories',
        message: 'Template categories refresh failed.',
        error: error,
        stackTrace: stackTrace,
        context: {
          'screenVisible': isScreenVisible(),
          'requestVersion': requestVersion,
        },
      );
    }
  }

  Future<void> loadTemplateOfTheDay(int requestVersion) async {
    final current = readState();
    writeState(
      current.copyWith(
        isTemplateOfTheDayLoading: current.templateOfTheDay == null,
        clearTemplateOfTheDayError: true,
      ),
    );
    try {
      final template = await repository().fetchTemplateOfTheDay();
      if (!_isCurrentRequest(requestVersion)) return;
      writeState(
        readState().copyWith(
          templateOfTheDay: template,
          isTemplateOfTheDayLoading: false,
          clearTemplateOfTheDayError: true,
        ),
      );
      final previewUrl = TemplatesFeedPolicy.normalizeMediaUrl(
        template?.thumbnailUrl ?? template?.previewMediaUrl,
      );
      if (isScreenVisible() && previewUrl != null && !isVideoUrl(previewUrl)) {
        unawaited(_warmThumbnail(previewUrl));
      }
    } catch (error, stackTrace) {
      if (!_isCurrentRequest(requestVersion)) return;
      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'load',
        message: 'Template of the Day load failed',
        error: error,
        stackTrace: stackTrace,
      );
      writeState(
        readState().copyWith(
          templateOfTheDay: null,
          isTemplateOfTheDayLoading: false,
          templateOfTheDayError: 'templates.template_of_the_day_load_failed',
        ),
      );
    }
  }

  bool _isCurrentRequest(int requestVersion) {
    return isMounted() &&
        isScreenVisible() &&
        requestVersion == currentRequestVersion();
  }

  Future<void> _warmThumbnail(String url) async {
    try {
      await warmupThumbnail(url);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'thumbnail_warmup',
        message: 'Template of the Day thumbnail warmup failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
