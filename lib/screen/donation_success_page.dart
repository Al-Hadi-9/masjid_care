import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

class DonationSuccessPage extends StatelessWidget {
  final String transactionId;
  final String amount;
  final String donationType;

  const DonationSuccessPage({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.donationType,
  });

  String _displayType(BuildContext c) {
    final isBn = SettingsService.instance.isBangla;
    if (isBn) return donationType;
    switch (donationType) {
      case 'যাকাত':
        return Tr.donationTypeZakat(c);
      case 'মসজিদ':
        return Tr.donationTypeMasjid(c);
      case 'মাদ্রাসা':
        return Tr.donationTypeMadrasa(c);
      case 'অন্যান্য':
        return Tr.donationTypeOther(c);
      default:
        return donationType;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF009688);
    const Color primaryDark = Color(0xFF004D40);
    final fmt = NumberFormat('#,##0.00');

    // Make this page rebuild when language toggles.
    SettingsScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: accentColor,
                  size: 100,
                ),
                const SizedBox(height: 20),
                Text(
                  Tr.donationSuccessTitle(context),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryDark,
                  ),
                ),
                const SizedBox(height: 20),

                _kv(Tr.donationTypeLabel(context), _displayType(context)),
                const SizedBox(height: 10),
                _kv(
                  Tr.donationAmountLabel(context),
                  '৳ ${fmt.format(double.tryParse(amount) ?? 0)}',
                ),
                const SizedBox(height: 10),
                _kv(Tr.donationTransactionId(context), '#$transactionId'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: Text(
                      Tr.donationOk(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        Flexible(
          child: Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
