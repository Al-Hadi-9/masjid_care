import 'dart:convert';
import 'package:http/http.dart' as http;

/// SSLCommerz gateway service.
///
/// Talks to your self-hosted PHP backend (see backend/sslcommerz_gateway.php).
/// The base URL MUST be injected at build time, e.g.:
///   flutter build apk --dart-define=GATEWAY_BASE_URL=https://your-host.com/sslcommerz_gateway.php
///
/// Why a backend? SSLCommerz requires `store_id` + `store_password` to be sent
/// server-side. They cannot live in the mobile app. Your PHP file holds them
/// (see the "sslcommerz.store_id" / "sslcommerz.store_password" constants in
/// backend/sslcommerz_gateway.php).
class SslCommerzService {
  // Compile-time injected by `--dart-define=GATEWAY_BASE_URL=...`
  // Default below is a placeholder so the app still compiles without the flag.
  static const String _baseUrl = String.fromEnvironment(
    'GATEWAY_BASE_URL',
    defaultValue: 'https://alhadi.olivosoft.com/sslcommerz_gateway.php',
  );

  /// Ask backend to create a sandbox session and return gateway URL + tran_id.
  Future<SslSession> createSession({
    required double amount,
    required String donationType,
    String customerName = 'Donor',
    String customerEmail = 'donor@example.com',
    String customerPhone = '01700000000',
  }) async {
    final uri = Uri.parse('$_baseUrl?action=create_session');
    final body = jsonEncode({
      'amount': amount.toStringAsFixed(2),
      'donationType': donationType,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
    });
    final headers = {'Content-Type': 'application/json'};

    // One quick retry on transient network errors so flaky mobile
    // connections don't push the user back to the form. Behavior is
    // unchanged — if both attempts fail, the same exception bubbles up.
    http.Response resp;
    try {
      resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
    }

    if (resp.statusCode != 200) {
      throw Exception(
        'Gateway create_session failed (${resp.statusCode}): ${resp.body}',
      );
    }

    final parsed = jsonDecode(resp.body) as Map<String, dynamic>;
    if (parsed['gatewayUrl'] == null ||
        (parsed['gatewayUrl'] as String).isEmpty) {
      throw Exception('Invalid gateway response: ${resp.body}');
    }

    return SslSession(
      gatewayUrl: parsed['gatewayUrl'] as String,
      transactionId: parsed['transactionId'] as String? ?? '',
      sessionId: parsed['sessionId'] as String? ?? '',
    );
  }
}

class SslSession {
  final String gatewayUrl;
  final String transactionId;
  final String sessionId;

  const SslSession({
    required this.gatewayUrl,
    required this.transactionId,
    required this.sessionId,
  });
}
