class AppException implements Exception {
  const AppException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'AppException($statusCode): $message';
}

class RequestCancelledException extends AppException {
  const RequestCancelledException([super.message = 'Request cancelled.']);
}
