class AppException implements Exception {
  const AppException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'AppException($statusCode): $message';
}

extension AppExceptionSupportX on AppException {
  bool get isSupportConversationNotFound {
    if (statusCode == 404) {
      return true;
    }

    return message.trim().toLowerCase().contains(
      'support.conversation_not_found',
    );
  }

  bool get isRequestCancelled {
    return this is RequestCancelledException ||
        message.trim().toLowerCase() == 'request_cancelled';
  }
}

class RequestCancelledException extends AppException {
  const RequestCancelledException([super.message = 'request_cancelled']);
}

class GenerationWaitTooLongException extends AppException {
  const GenerationWaitTooLongException({
    this.mediaType,
    this.tier,
    this.estimatedWaitSeconds,
    this.maxAllowedWaitSeconds,
    this.retryAfterSeconds,
    this.canRetry = false,
    this.canUpgradeForPriority = false,
    super.statusCode,
    super.cause,
  }) : super('templates.generation_wait_too_long');

  final String? mediaType;
  final String? tier;
  final int? estimatedWaitSeconds;
  final int? maxAllowedWaitSeconds;
  final int? retryAfterSeconds;
  final bool canRetry;
  final bool canUpgradeForPriority;
}
