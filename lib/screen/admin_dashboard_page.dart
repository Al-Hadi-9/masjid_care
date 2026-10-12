import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/masjid_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';
import 'add_income_page_manual.dart';
import 'add_expense_page.dart';
import 'donation_list_page.dart';
import 'expense_list_page.dart';
import 'app_shell.dart';
import 'admin_requests_page.dart';
import 'yearly_finance_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirestoreService _firestoreService = FirestoreService();
  double totalIncome = 0, totalExpense = 0;
  double openingBalance = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
    _loadJamaatTimes();
  }

  Future<void> _loadJamaatTimes() async {
    await MasjidService.instance.loadJamaatTimes();
  }

  Future<void> loadDashboard() async {
    final current = await _firestoreService.getYearlyFinanceSummary(
      DateTime.now().year,
    );
    if (!mounted) return;
    setState(() {
      totalIncome = current.income;
      totalExpense = current.expense;
      openingBalance = current.openingBalance;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: SettingsService.instance.isBangla
            ? 'অ্যাডমিন প্যানেল'
            : 'Admin Panel',
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BalanceCard(
              balance: totalIncome - totalExpense,
              income: totalIncome,
              expense: totalExpense,
              openingBalance: openingBalance,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Add Income',
                    icon: Icons.add,
                    color: const Color(0xFF16804F),
                    onTap: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddIncomePage(),
                        ),
                      );
                      if (saved == true && mounted) {
                        _showFinanceSavedMessage(isIncome: true);
                      }
                      loadDashboard();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Add Expense',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFFB8442D),
                    onTap: () async {
                      final saved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddExpensePage(),
                        ),
                      );
                      if (saved == true && mounted) {
                        _showFinanceSavedMessage(isIncome: false);
                      }
                      loadDashboard();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Lists and approvals',
              style: TextStyle(
                color: Color(0xFF52615D),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.calendar_month_outlined,
                  iconColor: const Color(0xFF16804F),
                  title: SettingsService.instance.isBangla
                      ? 'বছরভিত্তিক আর্থিক হিসাব'
                      : 'Yearly financial summary',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const YearlyFinancePage(),
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.schedule,
                  iconColor: const Color(0xFF16804F),
                  title: SettingsService.instance.isBangla
                      ? 'জামাতের সময় পরিবর্তন'
                      : 'Edit Jamaat Times',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JamaatTimeSettingsPage(),
                    ),
                  ).then((_) => _loadJamaatTimes()),
                ),
                _MenuTile(
                  icon: Icons.favorite_border,
                  iconColor: const Color(0xFF16804F),
                  title: 'Donation List',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DonationListPage()),
                  ),
                ),
                _MenuTile(
                  icon: Icons.receipt_long,
                  iconColor: const Color(0xFFD79222),
                  title: 'Expense List',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExpenseListPage()),
                  ),
                ),
                _MenuTile(
                  icon: Icons.admin_panel_settings_outlined,
                  iconColor: const Color(0xFF526FC4),
                  title: 'Admin Request Approve',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminRequestsPage(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await AuthService().logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const AppShell(initialIndex: 0),
                  ),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout, size: 17),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB8442D),
                minimumSize: const Size.fromHeight(44),
                backgroundColor: const Color(0xFFFFF7F5),
                side: const BorderSide(color: Color(0xFFF0C9C0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _DangerZone(
              onDeleteAccount: _deleteAdminAccount,
              onDeleteMasjid: _deleteMasjid,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAdminAccount() async {
    final isBangla = SettingsService.instance.isBangla;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isBangla ? 'অ্যাকাউন্ট মুছে ফেলবেন?' : 'Delete account?'),
        content: Text(
          isBangla
              ? 'আপনি কি admin থেকে অব্যাহতি চান?'
              : 'Do you want to resign as an admin?',
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isBangla ? 'বাতিল' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isBangla ? 'অ্যাকাউন্ট মুছুন' : 'Delete Account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AuthService().deleteCurrentAdminAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBangla ? 'অ্যাকাউন্ট মুছে ফেলা হয়েছে' : 'Account deleted',
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 0)),
          (_) => false,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteMasjid() async {
    final understood = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Tr.settingsDeleteWarningTitle(context)),
        content: Text(Tr.settingsDeleteWarning(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(Tr.settingsDeleteCancel(context)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(Tr.settingsDeleteContinue(context)),
          ),
        ],
      ),
    );
    if (understood != true || !mounted) return;

    final passwordController = TextEditingController();
    final session = await AuthService().currentSession();
    final requiresPassword =
        FirebaseAuth.instance.currentUser?.uid != session?['authUid'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Tr.settingsDeleteConfirmTitle(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Tr.settingsDeleteFinalConfirm(context)),
            if (requiresPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: SettingsService.instance.isBangla
                      ? 'স্রষ্টা অ্যাকাউন্টের পাসওয়ার্ড'
                      : 'Creator account password',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(Tr.settingsDeleteCancel(context)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(Tr.settingsDeleteConfirm(context)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      passwordController.dispose();
      return;
    }

    try {
      await MasjidService.instance.deleteCurrentMasjid(
        creatorPassword: passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Tr.settingsDeleteSuccess(context))),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 0)),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      if (error is StateError &&
          error.message.toString().contains(
            'Only the masjid account creator',
          )) {
        final isBangla = SettingsService.instance.isBangla;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.lock_outline, color: Color(0xFFB8442D)),
            title: Text(
              isBangla ? 'মসজিদ মুছতে পারবেন না' : 'Cannot delete masjid',
            ),
            content: Text(
              isBangla
                  ? 'শুধু যিনি মসজিদটি তৈরি করেছেন, তিনিই এটি মুছতে পারবেন।'
                  : 'Only the masjid account creator has permission to delete this masjid.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      final isBangla = SettingsService.instance.isBangla;
      final message = isBangla
          ? 'মসজিদ মুছতে সমস্যা হয়েছে। আবার চেষ্টা করুন।'
          : 'Could not delete the masjid. Please try again.';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Color(0xFFB8442D)),
          content: Text(message, textAlign: TextAlign.center),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      passwordController.dispose();
    }
  }

  void _showFinanceSavedMessage({required bool isIncome}) {
    final isBangla = SettingsService.instance.isBangla;
    final color = isIncome ? const Color(0xFF16804F) : const Color(0xFFB8442D);
    final message = isBangla
        ? (isIncome ? 'আয় সফলভাবে যোগ হয়েছে' : 'ব্যয় সফলভাবে যোগ হয়েছে')
        : (isIncome
              ? 'Income added successfully'
              : 'Expense added successfully');

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

class JamaatTimeSettingsPage extends StatefulWidget {
  const JamaatTimeSettingsPage({super.key});

  @override
  State<JamaatTimeSettingsPage> createState() => _JamaatTimeSettingsPageState();
}

class _JamaatTimeSettingsPageState extends State<JamaatTimeSettingsPage> {
  Map<String, String> _times = Map.from(MasjidService.defaultJamaatTimes);
  bool _loading = true;

  static const _prayers = [
    ('fajr', 'ফজর', 'Fajr', 'ভোর', 'Dawn', Icons.wb_twilight),
    ('dhuhr', 'যোহর', 'Dhuhr', 'দুপুর', 'Noon', Icons.wb_sunny),
    ('asr', 'আসর', 'Asr', 'বিকেল', 'Afternoon', Icons.cloud_outlined),
    (
      'maghrib',
      'মাগরিব',
      'Maghrib',
      'সন্ধ্যা',
      'Evening',
      Icons.nightlight_round,
    ),
    ('isha', 'এশা', 'Isha', 'রাত', 'Night', Icons.dark_mode),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    MasjidService.instance.addListener(_onTimesChanged);
  }

  @override
  void dispose() {
    MasjidService.instance.removeListener(_onTimesChanged);
    super.dispose();
  }

  Future<void> _load() async {
    await MasjidService.instance.loadJamaatTimes();
    if (mounted) {
      setState(() {
        _times = Map.from(MasjidService.instance.jamaatTimes);
        _loading = false;
      });
    }
  }

  void _onTimesChanged() {
    if (mounted) {
      setState(() => _times = Map.from(MasjidService.instance.jamaatTimes));
    }
  }

  Future<void> _editTime(String key) async {
    final current = (_times[key] ?? '05:20').split(':');
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(current[0]) ?? 5,
        minute: int.tryParse(current.length > 1 ? current[1] : '') ?? 20,
      ),
    );
    if (chosen == null) return;
    final updated = Map<String, String>.from(_times)
      ..[key] =
          '${chosen.hour.toString().padLeft(2, '0')}:${chosen.minute.toString().padLeft(2, '0')}';
    try {
      await MasjidService.instance.saveJamaatTimes(updated);
      if (!mounted) return;
      setState(() => _times = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SettingsService.instance.isBangla
                ? '??????? ???? ???????? ??????'
                : 'Jamaat time saved',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SettingsService.instance.isBangla
                ? '???? ??????? ??? ??????: $error'
                : 'Could not save time: $error',
          ),
        ),
      );
    }
  }

  String _formatTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return value;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    SettingsScope.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F7),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: SettingsService.instance.isBangla
            ? 'জামাতের সময় নির্বাচন'
            : 'Select Jamaat Times',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Text(
                    SettingsService.instance.isBangla
                        ? 'প্রতিটি নামাজের জামাতের সময় নির্ধারণ করুন'
                        : 'Set the congregation time for each prayer',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF52615D),
                    ),
                  ),
                ),
                for (final prayer in _prayers)
                  _JamaatSettingCard(
                    name: SettingsService.instance.isBangla
                        ? prayer.$2
                        : prayer.$3,
                    period: SettingsService.instance.isBangla
                        ? prayer.$4
                        : prayer.$5,
                    time: _formatTime(_times[prayer.$1] ?? '05:20'),
                    icon: prayer.$6,
                    onTap: () => _editTime(prayer.$1),
                  ),
              ],
            ),
    );
  }
}

class _JamaatSettingCard extends StatelessWidget {
  const _JamaatSettingCard({
    required this.name,
    required this.period,
    required this.time,
    required this.icon,
    required this.onTap,
  });
  final String name, period, time;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: const Color(0xFF1B5E4E), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  period,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 16)),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1B5E4E)),
          ),
        ],
      ),
    ),
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
    required this.openingBalance,
  });

  final double balance;
  final double income;
  final double expense;
  final double openingBalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4538), Color(0xFF1B5E4E), Color(0xFF247864)],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                SettingsService.instance.isBangla
                    ? '${DateTime.now().year} সালের বর্তমান ব্যালেন্স'
                    : '${DateTime.now().year} Current Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFF008000),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '৳ ${balance.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Color(0xFF008000),
              fontSize: 32,
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
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.16)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BalanceValue(
                  label: 'Total income',
                  value: income,
                  icon: Icons.north_east_rounded,
                  color: const Color(0xFF38D39F),
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceValue(
                  label: 'Total expense',
                  value: expense,
                  icon: Icons.south_east_rounded,
                  color: const Color(0xFFFF8A80),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceValue extends StatelessWidget {
  const _BalanceValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '৳ ${value.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = label == 'Add Income';
    final isBangla = SettingsService.instance.isBangla;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBangla
                          ? (isIncome ? 'আয় যোগ করুন' : 'ব্যয় যোগ করুন')
                          : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBangla
                          ? (isIncome ? 'নতুন আয়ের তথ্য' : 'নতুন ব্যয়ের তথ্য')
                          : (isIncome ? 'Record income' : 'Record expense'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.onDeleteAccount,
    required this.onDeleteMasjid,
  });

  final VoidCallback onDeleteAccount;
  final VoidCallback onDeleteMasjid;

  @override
  Widget build(BuildContext context) {
    final isBangla = SettingsService.instance.isBangla;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F5),
        border: Border.all(color: const Color(0xFFF0C9C0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                isBangla ? 'বিপজ্জনক কাজ' : 'Danger Zone',
                style: const TextStyle(
                  color: Color(0xFFB8442D),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onDeleteAccount,
            icon: const Icon(Icons.person_remove_outlined, size: 18),
            label: Text(
              isBangla ? 'Admin Account Delete' : 'Admin Account Delete',
            ),
            style: _dangerButtonStyle(),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onDeleteMasjid,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(isBangla ? 'মসজিদ মুছুন' : 'Delete Masjid'),
            style: _dangerButtonStyle(),
          ),
        ],
      ),
    );
  }

  ButtonStyle _dangerButtonStyle() => OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFB8442D),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFF0B6AA)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}
