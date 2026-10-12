import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/app_appbar.dart';

/// Hosts the SSLCommerz hosted checkout page inside a WebView and
/// detects the success/fail/cancel redirect URLs (which point back to
/// your PHP backend's `?action=success|fail|cancel`).
///
/// Pop the result via Navigator.pop so the previous page can read:
///   - 'status' : 'success' | 'fail' | 'cancel' | 'error'
///   - 'tran_id': string|null
///   - 'amount' : string|null
class PaymentGatewayPage extends StatefulWidget {
  final String gatewayUrl;
  final String transactionId;
  final String pendingDocId;

  const PaymentGatewayPage({
    super.key,
    required this.gatewayUrl,
    required this.transactionId,
    required this.pendingDocId,
  });

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  late final WebViewController _controller;
  bool _settled = false;

  // Match against your PHP backend's redirect URLs. The string parts come
  // from `BASE_URL` + `?action=success|fail|cancel` in sslcommerz_gateway.php.
  // We do a fuzzy "contains" check so trailing querystring is OK.
  static const _successMarkers = ['?action=success', '/success'];
  static const _failMarkers = ['?action=fail', '/fail'];
  static const _cancelMarkers = ['?action=cancel', '/cancel'];

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..enableZoom(false)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        'Chrome/120.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => _maybeSettle(url),
          onPageFinished: (url) => _maybeSettle(url),
          onNavigationRequest: (req) {
            // Block any external browser-launching schemes inside the WebView
            if (req.url.startsWith('intent://') ||
                req.url.startsWith('market://')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (err) {
            // Stay silent unless the page fails to load entirely
            debugPrint('WebView error: ${err.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.gatewayUrl));
  }

  void _maybeSettle(String url) {
    if (_settled) return;
    final lower = url.toLowerCase();

    if (_anyMatches(lower, _successMarkers)) {
      _settled = true;
      _popWith('success');
    } else if (_anyMatches(lower, _failMarkers)) {
      _settled = true;
      _popWith('fail');
    } else if (_anyMatches(lower, _cancelMarkers)) {
      _settled = true;
      _popWith('cancel');
    }
  }

  bool _anyMatches(String url, List<String> markers) {
    for (final m in markers) {
      if (url.contains(m)) return true;
    }
    return false;
  }

  void _popWith(String status) {
    if (!mounted) return;
    Navigator.pop(context, {
      'status': status,
      'tran_id': widget.transactionId,
      'pendingDocId': widget.pendingDocId,
    });
  }

  Future<bool> _confirmExit() async {
    if (_settled) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('পেমেন্ট বাতিল করবেন?'),
        content: const Text(
          'পেমেন্ট প্রক্রিয়া এখনো সম্পন্ন হয়নি। বের হতে চান?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('না, চালিয়ে যান'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('হ্যাঁ, বাতিল'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _popWith('cancel');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExit();
      },
      child: Scaffold(
        appBar: AppAppBar(
          title: AppAppBar.kMasjidName,
          subtitle: 'নিরাপদ পেমেন্ট (SSLCommerz)',
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ],
        ),
      ),
    );
  }
}
