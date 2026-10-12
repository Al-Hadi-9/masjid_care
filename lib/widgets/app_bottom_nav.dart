import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// Persistent bottom navigation bar.
///
/// Stateless by design — the parent shell owns the active index and
/// tab switching is done by swapping the visible page in an IndexedStack.
/// Keeping the navigation logic out of this widget means the same widget
/// could be reused if you ever introduce a different shell.
///
/// Labels are pulled from [Tr] so they switch between Bangla and English
/// based on the user's choice in Settings.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;

  /// Called when the user taps a different tab. Same-tab taps are
  /// filtered out before reaching the parent so it never causes a
  /// setState.
  final ValueChanged<int> onTap;

  static const Color _background = Color(0xFF165445);
  static const Color _selected = Color(0xFF66BB6A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: _background,
          selectedItemColor: _selected,
          unselectedItemColor: Colors.white.withValues(alpha: 0.65),
          selectedFontSize: 12,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          currentIndex: currentIndex,
          elevation: 0,
          // The bottom navigation bar's default tap handler already ignores
          // taps on the active item, so we forward directly.
          onTap: onTap,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: Tr.navHome(context),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet_rounded),
              label: Tr.navFinance(context),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.menu_book_outlined),
              activeIcon: const Icon(Icons.menu_book_rounded),
              label: Tr.navLibrary(context),
            ),
          ],
        ),
      ),
    );
  }
}
