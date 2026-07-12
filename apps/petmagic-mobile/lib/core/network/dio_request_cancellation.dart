import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';

extension DioRequestCancellationAdapter on RequestCancellation? {
  CancelToken? toDioCancelToken() {
    final cancellation = this;
    if (cancellation == null) return null;

    final token = CancelToken();
    void cancelDio(Object? reason) {
      if (!token.isCancelled) token.cancel(reason);
    }

    cancellation.addListener(cancelDio);
    return token;
  }
}
