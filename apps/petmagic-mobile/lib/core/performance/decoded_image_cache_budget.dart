import 'package:flutter/widgets.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';

void configureDecodedImageCacheBudget({ImageCache? imageCache}) {
  final cache = imageCache ?? PaintingBinding.instance.imageCache;
  cache.maximumSize = AppConfig.decodedImageCacheMaxObjectsSafe;
  cache.maximumSizeBytes = AppConfig.decodedImageCacheMaxBytesSafe;
}

void trimDecodedImageCache({ImageCache? imageCache}) {
  final cache = imageCache ?? PaintingBinding.instance.imageCache;
  cache.clear();
  cache.clearLiveImages();
}

class DecodedImageCacheLifecycleObserver extends StatefulWidget {
  const DecodedImageCacheLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  State<DecodedImageCacheLifecycleObserver> createState() =>
      _DecodedImageCacheLifecycleObserverState();
}

class _DecodedImageCacheLifecycleObserverState
    extends State<DecodedImageCacheLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      configureDecodedImageCacheBudget();
      return;
    }

    trimDecodedImageCache();
  }

  @override
  void didHaveMemoryPressure() {
    trimDecodedImageCache();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
