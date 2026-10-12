import 'dart:async';

import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'add_income_page_manual.dart';
import 'add_expense_page.dart';
import 'donation_list_page.dart';
import 'expense_list_page.dart';
import 'yearly_finance_page.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final FirestoreService firestoreService = FirestoreService();

  double totalIncome = 0;
  double totalExpense = 0;
  double openingBalance = 0;
  bool _isAdmin = false;

  StreamSubscription? _donationSub;
  StreamSubscription? _expenseSub;
  StreamSubscription? _manualIncomeSub;

  @override
  void initState() {
    super.initState();
    _loadAdminAccess();
    loadFinance();
    listenFinance();
  }

  Future<void> _loadAdminAccess() async {
    final session = await AuthService().currentSession();
    if (!mounted) return;
    setState(() => _isAdmin = session?['role'] == 'admin');
  }

  @override
  void dispose() {
    _donationSub?.cancel();
    _expenseSub?.cancel();
    _manualIncomeSub?.cancel();
    super.dispose();
  }

  Future<void> loadFinance() async {
    final summary = await firestoreService.getYearlyFinanceSummary(
      DateTime.now().year,
    );
    totalIncome = summary.income;
    totalExpense = summary.expense;
    openingBalance = summary.openingBalance;

    if (mounted) {
      setState(() {});
    }
  }

  void listenFinance() {
    _donationSub = firestoreService.getDonations().listen((_) {
      if (mounted) loadFinance();
    });
    _expenseSub = firestoreService.getExpenses().listen((_) {
      if (mounted) loadFinance();
    });
    _manualIncomeSub = firestoreService.getManualIncomes().listen((_) {
      if (mounted) loadFinance();
    });
  }

  Widget buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget buildButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
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
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double balance = totalIncome - totalExpense;

    // Subscribe to language toggle so finance summary cards flip with the user
    // setting without a manual setState on the page.
    final settings = SettingsScope.of(context);
    final isBn = settings.isBangla;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      // Persistent AppBar/BottomNav live in [AppShell].
      body: RefreshIndicator(
        onRefresh: loadFinance,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Hero Financial Card
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F4538),
                    Color(0xFF1B5E4E),
                    Color(0xFF247864),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B5E4E).withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBn
                            ? '${DateTime.now().year} সালের বর্তমান ব্যালেন্স'
                            : '${DateTime.now().year} Current Balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFF008000),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "৳ ${balance.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Color(0xFF008000),
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (openingBalance.abs() >= 0.005) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${openingBalance > 0 ? 'Previous year remaining' : 'Previous year deficit'}: ৳ ${openingBalance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Total Income
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF38D39F,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                color: Color(0xFF38D39F),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Tr.financeTotalIncome(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "৳ ${totalIncome.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      const SizedBox(width: 12),
                      // Total Expense
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFF8A80,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                color: Color(0xFFFF8A80),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Tr.financeTotalExpense(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "৳ ${totalExpense.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_isAdmin) ...[
              buildButton(
                title: isBn ? 'আয় যোগ করুন' : 'Add Income',
                subtitle: isBn
                    ? 'মসজিদের আয়ের হিসাব যোগ করুন'
                    : 'Record masjid income',
                icon: Icons.add_circle_outline,
                iconColor: const Color(0xFF16804F),
                iconBg: const Color(0xFFE8F5E9),
                onTap: () async {
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddIncomePage()),
                  );
                  if (saved == true) await loadFinance();
                },
              ),
              const SizedBox(height: 12),
              buildButton(
                title: isBn ? 'ব্যয় যোগ করুন' : 'Add Expense',
                subtitle: isBn
                    ? 'মসজিদের ব্যয়ের হিসাব যোগ করুন'
                    : 'Record masjid expense',
                icon: Icons.post_add_rounded,
                iconColor: const Color(0xFFB8442D),
                iconBg: const Color(0xFFFFF0EC),
                onTap: () async {
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddExpensePage()),
                  );
                  if (saved == true) await loadFinance();
                },
              ),
              const SizedBox(height: 24),
            ],

            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                isBn ? 'আর্থিক বিবরণী' : 'Financial Records',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),

            buildButton(
              title: isBn ? "অনুদানের তালিকা" : "Donation List",
              subtitle: isBn
                  ? "সকল জমার হিসাব ও বিস্তারিত তথ্য"
                  : "All donation records and details",
              icon: Icons.volunteer_activism_rounded,
              iconColor: const Color(0xFF1B5E4E),
              iconBg: const Color(0xFFE8F5E9),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DonationListPage(readOnly: true),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            buildButton(
              title: isBn ? "খরচের তালিকা" : "Expense List",
              subtitle: isBn
                  ? "মসজিদের যাবতীয় খরচের বিবরণ"
                  : "All masjid expense records and receipts",
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF2E7D32),
              iconBg: const Color(0xFFE8F5E9),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExpenseListPage(readOnly: true),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            buildButton(
              title: isBn
                  ? 'বছরভিত্তিক আর্থিক হিসাব'
                  : 'Yearly financial summary',
              subtitle: isBn
                  ? 'প্রতি বছরের আয়-ব্যয় ও অবশিষ্ট হিসাব'
                  : 'Income, expense and balance for each year',
              icon: Icons.calendar_month_outlined,
              iconColor: const Color(0xFF1B5E4E),
              iconBg: const Color(0xFFE0F2EC),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const YearlyFinancePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
