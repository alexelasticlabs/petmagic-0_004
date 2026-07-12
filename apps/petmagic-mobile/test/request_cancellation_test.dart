import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';

void main() {
  test('cancellation notifies each listener once and retains the reason', () {
    final cancellation = RequestCancellation();
    final reasons = <Object?>[];

    cancellation.addListener(reasons.add);
    cancellation.cancel('disposed');
    cancellation.cancel('ignored');

    expect(cancellation.isCancelled, isTrue);
    expect(cancellation.reason, 'disposed');
    expect(reasons, ['disposed']);
  });

  test('late listener observes an already cancelled request', () {
    final cancellation = RequestCancellation()..cancel('already_done');
    Object? reason;

    cancellation.addListener((value) => reason = value);

    expect(reason, 'already_done');
  });

  test('Dio adapter propagates application cancellation', () {
    final cancellation = RequestCancellation();
    final token = cancellation.toDioCancelToken();

    cancellation.cancel('screen_disposed');

    expect(token, isNotNull);
    expect(token!.isCancelled, isTrue);
    expect(token.cancelError, isA<DioException>());
  });
}
