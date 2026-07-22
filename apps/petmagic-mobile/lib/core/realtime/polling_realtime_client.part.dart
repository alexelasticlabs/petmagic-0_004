part of 'realtime_client.dart';

class PollingRealtimeClient implements RealtimeClient {
  PollingRealtimeClient({
    this.interval = const Duration(seconds: 20),
    this.topics = const [RealtimeTopics.templatesFeedInvalidated],
  });

  final Duration interval;
  final List<String> topics;

  StreamController<RealtimeEvent>? _controller;
  Timer? _timer;
  int _connectionHolders = 0;

  @override
  Stream<RealtimeEvent> get events =>
      (_controller ??= StreamController<RealtimeEvent>.broadcast()).stream;

  @override
  Future<void> connect() async {
    _connectionHolders++;
    if (_timer != null) {
      return;
    }

    _scheduleNextPoll();
  }

  @override
  Future<void> disconnect() async {
    if (_connectionHolders == 0) {
      return;
    }

    _connectionHolders--;
    if (_connectionHolders > 0) {
      return;
    }

    _timer?.cancel();
    _timer = null;

    final controller = _controller;
    _controller = null;
    await controller?.close();
  }

  void _scheduleNextPoll() {
    _timer?.cancel();
    _timer = null;
    if (_connectionHolders == 0) {
      return;
    }

    _timer = Timer(interval, () {
      _timer = null;
      final controller = _controller ??=
          StreamController<RealtimeEvent>.broadcast();
      if (controller.isClosed || _connectionHolders == 0) {
        return;
      }

      for (final topic in topics) {
        controller.add(RealtimeEvent(topic: topic));
      }
      _scheduleNextPoll();
    });
  }
}
