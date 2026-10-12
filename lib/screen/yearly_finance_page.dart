import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

class YearlyFinancePage extends StatefulWidget {
  const YearlyFinancePage({super.key});

  @override
  State<YearlyFinancePage> createState() => _YearlyFinancePageState();
}

class _YearlyFinancePageState extends State<YearlyFinancePage> {
  final FirestoreService _firestore = FirestoreService();
  List<YearFinanceSummary> _summaries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summaries = await _firestore.getYearlyFinanceSummaries();
      if (!mounted) return;
      setState(() {
        _summaries = summaries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = SettingsService.instance.isBangla
            ? 'বার্ষিক হিসাব লোড করা যায়নি। আবার চেষ্টা করুন।'
            : 'Could not load yearly accounts. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.of(context);
    final isBangla = SettingsService.instance.isBangla;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: isBangla
            ? 'বছরভিত্তিক আর্থিক হিসাব'
            : 'Yearly financial summary',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadSummaries,
                    child: Text(isBangla ? 'আবার চেষ্টা করুন' : 'Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSummaries,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      isBangla
                          ? 'প্রতি বছরের আয়, ব্যয় ও উদ্বৃত্ত/ঘাটতি'
                          : 'Income, expense and surplus or deficit by year',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF52615D),
                      ),
                    ),
                  ),
                  if (_summaries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          isBangla
                              ? 'কোনো হিসাব পাওয়া যায়নি'
                              : 'No yearly accounts found',
                        ),
                      ),
                    ),
                  for (final summary in _summaries)
                    _YearlyFinanceItem(summary: summary, isBangla: isBangla),
                ],
              ),
            ),
    );
  }
}

class _YearlyFinanceItem extends StatelessWidget {
  const _YearlyFinanceItem({required this.summary, required this.isBangla});

  final YearFinanceSummary summary;
  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    final surplus = summary.balance > 0.005;
    final deficit = summary.balance < -0.005;
    final color = surplus
        ? const Color(0xFF16804F)
        : deficit
        ? const Color(0xFFB8442D)
        : const Color(0xFF64748B);
    final status = surplus
        ? (isBangla ? 'উদ্বৃত্ত' : 'Surplus')
        : deficit
        ? (isBangla ? 'ঘাটতি' : 'Deficit')
        : (isBangla ? 'সমান' : 'Balanced');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Text(
              '${summary.year}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E4E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AmountLine(
                  label: isBangla ? 'মোট আয়' : 'Total income',
                  amount: summary.income,
                  color: const Color(0xFF16804F),
                ),
                const SizedBox(height: 5),
                _AmountLine(
                  label: isBangla ? 'মোট ব্যয়' : 'Total expense',
                  amount: summary.expense,
                  color: const Color(0xFFB8442D),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 82),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Column(
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '৳ ${summary.balance.abs().toStringAsFixed(0)}',
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          '৳ ${amount.toStringAsFixed(0)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}
