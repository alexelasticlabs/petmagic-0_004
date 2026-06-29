part of 'generation_status_page.dart';

extension _GenerationStatusPageFeedbackActions on _GenerationStatusPageState {
  Future<void> _handleRatingSelected(int rating) async {
    final generation = _generation;
    if (generation == null) {
      return;
    }

    unawaited(_recordFeedbackRatingSelected(generation, rating));

    if (rating > 1) {
      await _submitFeedback(generation, rating, const [], null);
      return;
    }

    final result = await showPetMagicModalBottomSheet<_FeedbackResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context, bottomInset) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: const _NegativeFeedbackSheet(),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    await _submitFeedback(generation, rating, result.reasons, result.comment);
  }

  Future<void> _submitFeedback(
    TemplateGenerationResult generation,
    int rating,
    List<String> reasons,
    String? comment,
  ) async {
    if (!mounted) {
      return;
    }

    _setPageState(() => _isSubmittingFeedback = true);
    try {
      await ref
          .read(generationHistoryControllerProvider.notifier)
          .submitFeedback(
            generationId: generation.generationId,
            rating: rating,
            selectedReasons: reasons,
            comment: comment,
          );
      if (!mounted) {
        return;
      }

      PetMagicToast.show(
        context,
        message: AppLocalizations.of(
          context,
        ).generationStatusFeedbackThanksMessage,
        tone: PetMagicToastTone.success,
      );
    } on Object {
      unawaited(_recordFeedbackSubmitFailed(generation));
      rethrow;
    } finally {
      if (mounted) {
        _setPageState(() => _isSubmittingFeedback = false);
      }
    }
  }

  Future<void> _submitStructuredFeedback({
    required TemplateGenerationResult generation,
    required String type,
    required String category,
    required String sourceScreen,
    int? rating,
    String? message,
  }) async {
    if (!mounted || _isSubmittingFeedback) {
      return;
    }

    _setPageState(() => _isSubmittingFeedback = true);
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .submitFeedback(
            type: type,
            category: category,
            rating: rating,
            message: message,
            generationId: generation.generationId,
            templateId: generation.templateId,
            petId: generation.petId,
            sourceScreen: sourceScreen,
          );
      if (!mounted) {
        return;
      }

      PetMagicToast.show(
        context,
        message: AppLocalizations.of(
          context,
        ).generationStatusFeedbackThanksMessage,
        tone: PetMagicToastTone.success,
      );
    } on Object {
      unawaited(_recordFeedbackSubmitFailed(generation));
      rethrow;
    } finally {
      if (mounted) {
        _setPageState(() => _isSubmittingFeedback = false);
      }
    }
  }

  Future<void> _showReportProblemSheet(
    TemplateGenerationResult generation,
  ) async {
    unawaited(
      ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: 'feedback_report_clicked',
            generationId: generation.generationId,
          ),
    );

    final feedbackText = _feedbackText(context);
    final result = await showPetMagicModalBottomSheet<_FeedbackResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context, bottomInset) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _ProblemFeedbackSheet(
          title: feedbackText.reportTitle,
          reasons: feedbackText.reportReasons,
        ),
      ),
    );

    if (!mounted || result == null || result.reasons.isEmpty) {
      return;
    }

    final category = result.reasons.first;
    await _submitStructuredFeedback(
      generation: generation,
      type: category == 'payment' ? 'PaymentIssue' : 'BugReport',
      category: category,
      rating: -1,
      message: result.comment,
      sourceScreen: 'generation_result_report',
    );
  }

  Future<void> _recordFeedbackPromptViewed(
    TemplateGenerationResult generation,
  ) async {
    final key = '${generation.generationId}:feedback_prompt_viewed';
    if (!_recordedFeedbackPromptEvents.add(key)) {
      return;
    }

    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: 'feedback_prompt_viewed',
            generationId: generation.generationId,
            metadata: {
              'feedbackType': 'GenerationResult',
              'templateId': generation.templateId,
              'generationId': generation.generationId,
              'platform': Theme.of(context).platform.name,
              'userPlan': generation.userPlan,
            },
          );
    } on Object {
      // Best-effort analytics must not block the result screen.
    }
  }

  Future<void> _recordFeedbackRatingSelected(
    TemplateGenerationResult generation,
    int rating,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: 'feedback_rating_selected',
            generationId: generation.generationId,
            metadata: {
              'feedbackType': 'GenerationResult',
              'category': rating == 3
                  ? 'good'
                  : rating == 2
                  ? 'okay'
                  : 'bad',
              'rating': rating == 3
                  ? 1
                  : rating == 2
                  ? 0
                  : -1,
              'templateId': generation.templateId,
              'generationId': generation.generationId,
              'platform': Theme.of(context).platform.name,
              'userPlan': generation.userPlan,
            },
          );
    } on Object {
      // Best-effort analytics must not block feedback.
    }
  }

  Future<void> _recordFeedbackSubmitFailed(
    TemplateGenerationResult generation,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: 'feedback_submit_failed',
            generationId: generation.generationId,
            metadata: {
              'feedbackType': 'GenerationResult',
              'templateId': generation.templateId,
              'generationId': generation.generationId,
              'platform': Theme.of(context).platform.name,
              'userPlan': generation.userPlan,
            },
          );
    } on Object {
      // Best-effort analytics must not block feedback error handling.
    }
  }

  Future<void> _recordTemplateOfTheDayTerminalAnalytics(
    TemplateGenerationResult generation,
  ) async {
    final featured = widget.templateOfTheDay;
    if (featured == null || !generation.isTerminal) {
      return;
    }

    final eventType = generation.isCompleted
        ? 'generation_completed'
        : generation.isFailed
        ? 'generation_failed'
        : null;
    if (eventType == null) {
      return;
    }

    final key = '${generation.generationId}:$eventType';
    if (!_recordedTemplateOfTheDayTerminalEvents.add(key)) {
      return;
    }

    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: featured.templateId,
            eventType: eventType,
            generationId: generation.generationId,
            metadata: <String, Object?>{
              'templateId': featured.templateId,
              'type': featured.templateType.apiValue.toLowerCase(),
              'source': featured.source,
              'isPremium': featured.isPremium,
              'userPlan': generation.userPlan,
              'date': _templateOfTheDayDateValue(featured),
              'screen': 'generation_status',
              if (generation.failureCode != null &&
                  generation.failureCode!.isNotEmpty)
                'failureCode': generation.failureCode,
            },
          );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'generation_status_analytics',
        message:
            'Could not record Template of the Day terminal analytics event.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'eventType': eventType,
          'templateId': featured.templateId,
          'generationId': generation.generationId,
        },
      );
    }
  }
}

String _templateOfTheDayDateValue(TemplateOfTheDayItem featured) {
  final date = featured.date.toUtc();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
