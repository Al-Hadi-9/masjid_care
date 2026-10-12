import 'package:flutter/material.dart';
import 'donation_step2_page.dart';
import '../widgets/app_appbar.dart';
import '../services/settings_service.dart';

class DonationStep1Page extends StatefulWidget {
  const DonationStep1Page({super.key});

  @override
  State<DonationStep1Page> createState() => _DonationStep1PageState();
}

class _DonationStep1PageState extends State<DonationStep1Page> {
  String _displayType(BuildContext c, String bn) {
    final isBn = SettingsService.instance.isBangla;
    switch (bn) {
      case 'যাকাত':
        return isBn ? bn : Tr.donationTypeZakat(c);
      case 'মসজিদ':
        return isBn ? bn : Tr.donationTypeMasjid(c);
      case 'মাদ্রাসা':
        return isBn ? bn : Tr.donationTypeMadrasa(c);
      case 'অন্যান্য':
        return isBn ? bn : Tr.donationTypeOther(c);
      default:
        return bn;
    }
  }

  String selectedType = 'মসজিদ';
  TextEditingController amountController = TextEditingController();

  final List<Map<String, dynamic>> donationTypes = [
    {'bn': 'যাকাত', 'icon': Icons.payments_outlined},
    {'bn': 'মসজিদ', 'icon': Icons.mosque_outlined},
    {'bn': 'মাদ্রাসা', 'icon': Icons.school_outlined},
    {'bn': 'অন্যান্য', 'icon': Icons.favorite_border},
  ];

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF1B5E4E);

    // Subscribe to language changes so labels flip when the user toggles
    // Bangla <-> English in Settings.
    final settings = SettingsScope.of(context);
    final isBn = settings.isBangla;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE8EEF1)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Tr.donationProcess(context),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
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
                        width: 8,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
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
                  Text(
                    Tr.donationStep1(context),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 22),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.25,
                        ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final bnName = donationTypes[index]['bn'] as String;
                      final isSelected = selectedType == bnName;
                      return InkWell(
                        onTap: () => setState(() => selectedType = bnName),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF1F8F5) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: isSelected
                                ? Border.all(color: primary, width: 2)
                                : Border.all(color: const Color(0xFFE8EEF1), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? primary.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: isSelected ? 12 : 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primary.withValues(alpha: 0.12)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  donationTypes[index]['icon'],
                                  size: 28,
                                  color: isSelected
                                      ? primary
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isBn ? bnName : _displayType(context, bnName),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isSelected
                                      ? primary
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 26),

                  // Donation input box
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: Tr.donationAmountHint(context),
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
                      prefixText: '৳ ',
                      prefixStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

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
                      onPressed: () {
                        if (amountController.text.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DonationStep2Page(
                                amount: amountController.text,
                                donationType: selectedType,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(Tr.donationAmountRequired(context)),
                            ),
                          );
                        }
                      },
                      child: Text(
                        Tr.donationNextPayment(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
