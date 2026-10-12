import 'package:flutter/material.dart';
import 'donation_success_page.dart';
import 'payment_gateway_page.dart';
import '../services/firestore_service.dart';
import '../services/sslcommerz_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

class DonationStep2Page extends StatefulWidget {
  final String amount;
  final String donationType;

  const DonationStep2Page({
    super.key,
    required this.amount,
    required this.donationType,
  });

  @override
  State<DonationStep2Page> createState() => _DonationStep2PageState();
}

class _DonationStep2PageState extends State<DonationStep2Page> {
  final FirestoreService _firestoreService = FirestoreService();
  final SslCommerzService _ssl = SslCommerzService();

  final TextEditingController phoneController = TextEditingController();

  bool _busy = false;

  String _displayTypeLabel() {
    final isBn = SettingsService.instance.isBangla;
    if (isBn) return widget.donationType;
    switch (widget.donationType) {
      case 'যাকাত':
        return 'Zakat';
      case 'মসজিদ':
        return 'Mosque';
      case 'মাদ্রাসা':
        return 'Madrasa';
      case 'অন্যান্য':
        return 'Other';
      default:
        return widget.donationType;
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    if (_busy) return;

    final phone = phoneController.text.trim();
    if (phone.isEmpty || phone.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Tr.donationInvalidMobile(context))),
      );
      return;
    }

    final amount = double.tryParse(widget.amount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Tr.donationInvalidAmount(context))),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      // 1. Create the gateway session on our PHP backend.
      final session = await _ssl.createSession(
        amount: amount,
        donationType: widget.donationType,
        customerName: 'Donor',
        customerEmail: 'donor@example.com',
        customerPhone: phone,
      );

      // 2. Save a pending donation record in Firestore keyed by tran_id,
      //    so when payment completes we can flip its status.
      final pendingDocId = await _firestoreService.savePendingDonation(
        transactionId: session.transactionId,
        donationType: widget.donationType,
        amount: widget.amount,
        mobileNumber: phone,
        name: '',
        email: '',
      );

      if (!mounted) return;

      // 3. Launch the hosted SSLCommerz checkout inside a WebView.
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentGatewayPage(
            gatewayUrl: session.gatewayUrl,
            transactionId: session.transactionId,
            pendingDocId: pendingDocId,
          ),
        ),
      );

      if (!mounted) return;

      final status = result?['status'] as String? ?? 'cancel';
      final tranId = (result?['tran_id'] as String?) ?? session.transactionId;
      final docId = (result?['pendingDocId'] as String?) ?? pendingDocId;

      if (status == 'success') {
        await _firestoreService.markDonationCompleted(
          docId: docId,
          transactionId: tranId,
          amount: widget.amount,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DonationSuccessPage(
              transactionId: tranId,
              amount: widget.amount,
              donationType: widget.donationType,
            ),
          ),
        );
      } else if (status == 'fail') {
        await _firestoreService.markDonationFailed(
          docId: docId,
          transactionId: tranId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Tr.donationPayFailed(context))));
      } else {
        // cancel
        await _firestoreService.markDonationCancelled(
          docId: docId,
          transactionId: tranId,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF1B5E4E);

    // Trigger rebuild on language change.
    SettingsScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step or process indication
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  Tr.donationStep2(context),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Summary card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EEF1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Tr.donationTypeLabel(context),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _displayTypeLabel(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Tr.donationAmountLabel(context),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '৳ ${widget.amount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                Tr.donationMobileHint(context),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
                decoration: InputDecoration(
                  hintText: '01XXXXXXXXX',
                  prefixIcon: const Icon(Icons.phone_android_rounded, color: primary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: primary, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Payment-method hint
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD1E7DD)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        Tr.donationSslcommerzHint(context),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2C3E50),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _startPayment,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          Tr.donationPayNow(context),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
