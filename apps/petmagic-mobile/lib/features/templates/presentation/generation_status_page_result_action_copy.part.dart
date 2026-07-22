part of 'generation_status_page.dart';

enum _RemoveWatermarkAction { credit, credits, premium }

String _generateSimilarImageCostMessage(AppLocalizations text) =>
    text.generationStatusGenerateSimilarCost(1);

String _generateSimilarVideoCostMessage(AppLocalizations text) =>
    text.generationStatusGenerateSimilarCost(5);

String _generateSimilarConfirmLabel(AppLocalizations text) =>
    text.generationStatusGenerateSimilarConfirmAction;

String _cancelLabel(AppLocalizations text) =>
    text.generationStatusGenerateSimilarCancelAction;

String _sourceUnavailableMessage(AppLocalizations text) =>
    text.generationStatusGenerateSimilarSourceUnavailable;

String _insufficientCreditsMessage(AppLocalizations text) =>
    text.generationStatusGenerateSimilarInsufficientBalance;

String _generateSimilarGenericErrorMessage(AppLocalizations text) =>
    text.generationStatusGenerateSimilarFailed;

String _generateSimilarErrorMessage(AppLocalizations text, AppException error) {
  final message = error.message.toLowerCase();
  if (error.statusCode == 402 || message.contains('insufficient')) {
    return _insufficientCreditsMessage(text);
  }

  if (message.contains('source_media_unavailable') ||
      message.contains('generation_result_input_unavailable') ||
      message.contains('unavailable')) {
    return _sourceUnavailableMessage(text);
  }

  return _generateSimilarGenericErrorMessage(text);
}
