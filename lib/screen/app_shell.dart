import 'package:flutter/material.dart';

import 'home_page.dart';
import 'any_user.dart';
import 'library_page.dart';
import 'admin_auth_wrapper.dart';
import 'settings_page.dart';
import 'masjid_login_page.dart';
import '../services/settings_service.dart';
import '../services/masjid_service.dart';
import '../widgets/app_appbar.dart';
import '../widgets/app_bottom_nav.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Subtitle for the AppBar in each tab. Built dynamically so it can
  // pick up the user's language choice from SettingsService.
  List<String?> _subtitlesFor(BuildContext context, SettingsService s) => [
    null, // Home — masjid name only
    s.isBangla ? 'আয় - ব্যয়ের হিসাব' : 'Finance',
    Tr.tabSubtitleLibrary(context),
  ];

  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    // Rebuild when the user flips the language so the tab subtitle
    // swaps between Bangla and English.
    SettingsService.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  late final List<Widget> _pages = const [
    MyHomePage(),
    FinancePage(),
    LibraryPage(),
  ];

  void _onTap(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  void _openSettings() {
    // Close the drawer first so the pushed page doesn't sit over it.
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final subtitles = _subtitlesFor(context, settings);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: subtitles[_index],
        leading: Builder(
          builder: (innerContext) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: Tr.drawerHeader(innerContext),
            onPressed: () => Scaffold.of(innerContext).openDrawer(),
          ),
        ),
      ),
      drawer: _AppDrawer(onSettingsTap: _openSettings),
      body: Material(
        color: const Color(0xFFF6F8F9),
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _onTap),
    );
  }
}

/// Side-drawer navigation. Lists the app's main destinations plus a
/// Settings entry. Each entry is a tappable row that — except Settings —
/// switches the bottom-nav tab. Settings pushes a dedicated page.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header — brand block with the masjid name and a tagline.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F4538), Color(0xFF1B5E4E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.mosque_rounded,
                      color: Color(0xFF008000),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppAppBar.kMasjidName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Tr.drawerHeader(context),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Main list — navigation + settings entry.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: Color(0xFF1B5E4E),
                        size: 20,
                      ),
                    ),
                    title: Text(Tr.navHome(context)),
                    onTap: () {
                      Navigator.pop(context);
                      // Switch to Home tab. We can't reach setState
                      // from here directly; do it via a route lookup.
                      final shell = context
                          .findAncestorStateOfType<_AppShellState>();
                      shell?._onTap(0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.key, color: Color(0xFF1B5E4E)),
                    title: Text(s.isBangla ? 'মসজিদের টোকেন' : 'Masjid token'),
                    subtitle: Text(
                      '${AppAppBar.kMasjidName} • ${MasjidService.instance.masjidId}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(
                            s.isBangla ? 'মসজিদের টোকেন' : 'Masjid token',
                          ),
                          content: SelectableText(
                            MasjidService.instance.masjidId,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFF1B5E4E),
                    ),
                    title: Text(Tr.navFinance(context)),
                    onTap: () {
                      Navigator.pop(context);
                      final shell = context
                          .findAncestorStateOfType<_AppShellState>();
                      shell?._onTap(1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.menu_book,
                      color: Color(0xFF1B5E4E),
                    ),
                    title: Text(Tr.navLibrary(context)),
                    onTap: () {
                      Navigator.pop(context);
                      final shell = context
                          .findAncestorStateOfType<_AppShellState>();
                      shell?._onTap(2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Color(0xFF1B5E4E),
                    ),
                    title: Text(s.isBangla ? 'অ্যাডমিন' : 'Admin'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminAuthWrapper(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.settings,
                      color: Color(0xFF1B5E4E),
                    ),
                    title: Text(Tr.drawerSettings(context)),
                    onTap: onSettingsTap,
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      s.isBangla ? 'আমার মসজিদসমূহ' : 'My masjids',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E4E),
                      ),
                    ),
                  ),
                  ...MasjidService.instance.profiles.map(
                    (profile) => ListTile(
                      leading: const Icon(
                        Icons.radio_button_checked,
                        color: Color(0xFF1B5E4E),
                      ),
                      title: Text(
                        s.isBangla
                            ? profile['nameBangla'] ?? profile['nameEnglish']!
                            : profile['nameEnglish']!,
                      ),
                      subtitle: Text(profile['token']!),
                      onTap: () async {
                        await MasjidService.instance.setActiveMasjid(
                          profile['token']!,
                          nameBangla:
                              profile['nameBangla'] ?? profile['nameEnglish']!,
                          nameEnglish: profile['nameEnglish']!,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF1B5E4E),
                    ),
                    title: Text(
                      s.isBangla
                          ? 'আরেকটি মসজিদে যুক্ত হন'
                          : 'Join another masjid',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MasjidLoginPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: Text(
                      s.isBangla
                          ? 'বর্তমান মসজিদ থেকে প্রস্থান করুন'
                          : 'Exit current masjid',
                    ),
                    onTap: () => _logoutCurrentMasjid(context, s.isBangla),
                  ),
                ],
              ),
            ),
            // Footer — language indicator for quick visual feedback.
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.translate, size: 16, color: Colors.black45),
                  const SizedBox(width: 6),
                  Text(
                    s.currentLanguageLabel,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logoutCurrentMasjid(BuildContext context, bool isBangla) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isBangla
              ? 'বর্তমান মসজিদ থেকে প্রস্থান করবেন?'
              : 'Exit current masjid?',
        ),
        content: Text(
          isBangla
              ? 'শুধু বর্তমান মসজিদ profile সরানো হবে।'
              : 'Only the current masjid profile will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isBangla ? 'বাতিল' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isBangla ? 'প্রস্থান' : 'Exit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.pop(context);
    await MasjidService.instance.logoutCurrentMasjid();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MasjidService.instance.hasActiveMasjid
            ? const AppShell()
            : const MasjidLoginPage(),
      ),
      (_) => false,
    );
  }
}
