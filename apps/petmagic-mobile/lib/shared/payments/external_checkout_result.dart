enum ExternalCheckoutOutcome { completed, cancelled, failed }

class ExternalCheckoutResult {
  const ExternalCheckoutResult._({
    required this.outcome,
    this.error,
    this.errorMessage,
  });

  final ExternalCheckoutOutcome outcome;
  final Object? error;
  final String? errorMessage;

  bool get completed => outcome == ExternalCheckoutOutcome.completed;
  bool get cancelled => outcome == ExternalCheckoutOutcome.cancelled;

  static const ExternalCheckoutResult success = ExternalCheckoutResult._(
    outcome: ExternalCheckoutOutcome.completed,
  );

  static const ExternalCheckoutResult cancelledResult =
      ExternalCheckoutResult._(outcome: ExternalCheckoutOutcome.cancelled);

  factory ExternalCheckoutResult.failure({
    required Object error,
    String? errorMessage,
    bool isCancelled = false,
  }) {
    return ExternalCheckoutResult._(
      outcome: isCancelled
          ? ExternalCheckoutOutcome.cancelled
          : ExternalCheckoutOutcome.failed,
      error: error,
      errorMessage: errorMessage,
    );
  }
}
