import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Result of the Stripe checkout WebView session.
sealed class StripeCheckoutResult {
  const StripeCheckoutResult();
}

class StripeCheckoutSuccess extends StripeCheckoutResult {
  const StripeCheckoutSuccess({required this.sessionId});
  final String sessionId;
}

class StripeCheckoutCancelled extends StripeCheckoutResult {
  const StripeCheckoutCancelled();
}

class StripeCheckoutDismissed extends StripeCheckoutResult {
  const StripeCheckoutDismissed();
}

/// A full-screen in-app page that embeds Stripe Checkout in a WebView.
///
/// Intercepts `petmagic://checkout/success` and `petmagic://checkout/cancel`
/// navigation requests and closes itself with the appropriate result.
class StripeCheckoutPage extends StatefulWidget {
  const StripeCheckoutPage({required this.checkoutUrl, super.key});

  final String checkoutUrl;

  /// Push this page and await the result.
  static Future<StripeCheckoutResult> open(
    BuildContext context,
    String checkoutUrl,
  ) async {
    final result = await Navigator.of(context).push<StripeCheckoutResult>(
      MaterialPageRoute<StripeCheckoutResult>(
        fullscreenDialog: true,
        builder: (_) => StripeCheckoutPage(checkoutUrl: checkoutUrl),
      ),
    );
    return result ?? const StripeCheckoutDismissed();
  }

  @override
  State<StripeCheckoutPage> createState() => _StripeCheckoutPageState();
}

class _StripeCheckoutPageState extends State<StripeCheckoutPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // Ignore sub-resource errors; only act on main frame failures.
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && uri.scheme == 'petmagic') {
              _handlePetmagicUri(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _handlePetmagicUri(Uri uri) {
    if (!mounted) return;

    if (uri.host == 'checkout') {
      final path =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';

      if (path == 'success') {
        final sessionId = uri.queryParameters['session_id'] ?? '';
        Navigator.of(context).pop(
          StripeCheckoutSuccess(sessionId: sessionId),
        );
        return;
      }

      if (path == 'cancel') {
        Navigator.of(context).pop(const StripeCheckoutCancelled());
        return;
      }
    }

    // Unknown petmagic URI — dismiss.
    Navigator.of(context).pop(const StripeCheckoutDismissed());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              Navigator.of(context).pop(const StripeCheckoutDismissed()),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator.adaptive()),
        ],
      ),
    );
  }
}
