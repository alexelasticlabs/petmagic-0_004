import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionEpochProvider = NotifierProvider<SessionEpochController, int>(
  SessionEpochController.new,
);

final class SessionEpochController extends Notifier<int> {
  @override
  int build() => 0;

  void advance() => state++;
}
