import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/admin_service.dart';
import '../widgets/app_appbar.dart';
import '../widgets/app_bottom_nav.dart';
import 'app_shell.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController amountController = TextEditingController();

  final TextEditingController noteController = TextEditingController();

  final TextEditingController dateController = TextEditingController();

  DateTime? selectedDate;

  bool loading = false;

  Future<void> pickDate() async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dateController.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    dateController.dispose();
    super.dispose();
  }

  String selectedKhat = "বিদ্যুৎ বিল";
  final List<String> khatList = [
    "বিদ্যুৎ বিল",
    "ইমামের বেতন",
    "মুয়াজ্জিনের বেতন",
    "পরিষ্কার-পরিচ্ছন্নতা",
    "রক্ষণাবেক্ষণ",
    "অন্যান্য",
  ];

  Future<void> saveExpense() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("পরিমাণ লিখুন")));
      return;
    }

    try {
      setState(() {
        loading = true;
      });

      await _firestoreService.addExpense(
        khat: selectedKhat,
        amount: amountController.text.trim(),
        note: noteController.text.trim(),
        date: selectedDate,
        createdBy: AdminService.instance.currentAdminName,
        createdByEmail: AdminService.instance.currentAdminEmail,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xff00594c);

    return Scaffold(
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: 'নতুন খরচ যোগ করুন',
      ),

      backgroundColor: const Color(0xffF7F7F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedKhat,
              itemHeight: 48,
              decoration: InputDecoration(
                labelText: "খাত",
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              items: khatList.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: _KhatOption(
                    label: item,
                    icon: _expenseKhatIcon(item),
                    color: _expenseKhatColor(item),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedKhat = value!;
                });
              },
            ),

            const SizedBox(height: 24),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount",
                floatingLabelBehavior: FloatingLabelBehavior.always,
                prefixIcon: const Icon(Icons.payments_outlined),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: dateController,
              readOnly: true,
              onTap: pickDate,
              decoration: InputDecoration(
                labelText: "Date",
                floatingLabelBehavior: FloatingLabelBehavior.always,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: pickDate,
                ),
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: noteController,
              minLines: 5,
              maxLines: 7,
              decoration: InputDecoration(
                labelText: "Note",
                floatingLabelBehavior: FloatingLabelBehavior.always,
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),

            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(34),
                  ),
                ),

                onPressed: loading ? null : saveExpense,

                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNavigationBar(context),
    );
  }

  IconData _expenseKhatIcon(String khat) {
    switch (khat) {
      case 'বিদ্যুৎ বিল':
        return Icons.bolt_outlined;
      case 'ইমামের বেতন':
        return Icons.person_outline;
      case 'মুয়াজ্জিনের বেতন':
        return Icons.record_voice_over_outlined;
      case 'পরিষ্কার-পরিচ্ছন্নতা':
        return Icons.cleaning_services_outlined;
      case 'রক্ষণাবেক্ষণ':
        return Icons.build_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  Color _expenseKhatColor(String khat) {
    switch (khat) {
      case 'বিদ্যুৎ বিল':
        return const Color(0xFFD28A17);
      case 'ইমামের বেতন':
        return const Color(0xFF4B67B0);
      case 'মুয়াজ্জিনের বেতন':
        return const Color(0xFF16804F);
      case 'পরিষ্কার-পরিচ্ছন্নতা':
        return const Color(0xFF4B8E9D);
      case 'রক্ষণাবেক্ষণ':
        return const Color(0xFFB05A42);
      default:
        return const Color(0xFF65746E);
    }
  }

  Widget _bottomNavigationBar(BuildContext context) {
    return AppBottomNav(
      currentIndex: 1,
      onTap: (index) {
        if (index == 1) {
          Navigator.of(context).pop();
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AppShell(initialIndex: index)),
          (_) => false,
        );
      },
    );
  }
}

class _KhatOption extends StatelessWidget {
  const _KhatOption({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.zero,
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
