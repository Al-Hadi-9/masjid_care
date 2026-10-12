import 'package:flutter/material.dart';

import '../services/masjid_service.dart';
import '../services/settings_service.dart';

/// Shared, consistent AppBar used across the app.
///
/// Centralised so every screen has the same:
///   - toolbarHeight (smaller, more modern)
///   - title style (white, bold, single line)
///   - background colour
///   - icon colour
///   - elevation
///
/// Using this widget instead of building AppBar inline eliminates per-screen
/// duplication and makes a single-point tweak possible.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation = 0,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  /// Primary title — always rendered as the masjid name across every screen.
  final String title;

  /// Optional second line under the masjid name (e.g. 'হাদীস শরীফ').
  /// When non-null, the toolbar auto-grows so both lines fit cleanly.
  final String? subtitle;

  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;

  /// Set false when the page renders its own back button in the body
  /// (e.g. donation flow). Prevents a duplicate back arrow being
  /// auto-inserted by AppBar.
  final bool automaticallyImplyLeading;

  /// Optional widget rendered below the toolbar — typically a [TabBar]
  /// for tabbed pages (Dua/Zikir, Quran). The AppBar automatically
  /// grows to accommodate this widget's height.
  final PreferredSizeWidget? bottom;

  /// Height when only the primary title is rendered.
  static const double kToolbarHeight = 52;

  /// Height when both the primary title and the subtitle are rendered.
  static const double kToolbarHeightWithSubtitle = 64;

  /// The single canonical name of the masjid. Every screen in the app
  /// shows this string as its primary AppBar title — it is the brand
  /// anchor of the UI and must never be replaced with a page-specific
  /// heading.
  ///
  /// This is now a *live* getter, backed by [MasjidService], so when the
  /// admin updates the name in Settings it propagates to every visible
  /// AppBar on the next frame. Previously this was a hardcoded constant;
  /// the identifier is preserved for source-compat at call sites.
  static String get kMasjidName => SettingsService.instance.isBangla
      ? MasjidService.instance.masjidNameBangla
      : MasjidService.instance.masjidNameEnglish;

  static const Color _primary = Color(0xFF1B5E4E);

  @override
  Size get preferredSize => Size.fromHeight(
    (subtitle == null ? kToolbarHeight : kToolbarHeightWithSubtitle) +
        (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    // Wrap the AppBar in a Material so the entire preferred-size rect is
    // painted with the primary colour. Without this, the area *behind*
    // the AppBar's own Material (during a frame the AppBar is being
    // repainted, e.g. on tab switch) can show through as white.
    return Material(
      color: _primary,
      elevation: 0,
      child: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: centerTitle,
        elevation: 0,
        // Material 3 tints the AppBar with `surfaceTintColor` by default
        // when content scrolls behind it. That tint can briefly render
        // as a lighter band right after the AppBar is rebuilt, which is
        // one source of the white "flash" people see on tab change.
        surfaceTintColor: Colors.transparent,
        // The drop shadow under the AppBar is drawn by Material, not the
        // AppBar itself. Even with elevation: 0 a tiny shadow can still
        // slip through on some Flutter versions; nulling `shadowColor`
        // removes it entirely.
        shadowColor: Colors.transparent,
        toolbarHeight: subtitle == null
            ? kToolbarHeight
            : kToolbarHeightWithSubtitle,
        titleSpacing: 0,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
        bottom: bottom,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared, app-wide design tokens.
///
/// Pulled out of individual screens so spacing, radii and elevation stay
/// consistent and screens are trivially themable from one file.
class AppTokens {
  AppTokens._();

  // Brand colours
  static const Color primary = Color(0xFF1B5E4E);
  static const Color primaryDark = Color(0xFF0F4538);
  static const Color primaryLight = Color(0xFF267563);
  static const Color accent = Color(0xFF38D39F);
  static const Color accentGold = Color(0xFF008000);
  static const Color surface = Color(0xFFF6F8F9);
  static const Color surfaceAlt = Color(0xFFEEF2F5);
  static const Color card = Colors.white;
  static const Color cardDark = Color(0xFF243342);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F4538), Color(0xFF1B5E4E), Color(0xFF237763)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFFAFBFB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient silverGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF3F5F8),
      Color(0xFFE2E7EC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.45, 1.0],
  );

  static const Color borderSilver = Color(0xFFCFD8DF);

  // Soft shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF1B5E4E).withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get silverShadow => [
    BoxShadow(
      color: const Color(0xFF64748B).withValues(alpha: 0.16),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.8),
      blurRadius: 2,
      offset: const Offset(0, -1),
    ),
  ];

  // Spacing scale (4 / 8 / 12 / 16 / 20 / 24 / 32)
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // Radii
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r25 = 25;

  // Elevations
  static const double e0 = 0;
  static const double e2 = 2;
  static const double e3 = 3;

  // Branding lives on [AppAppBar.kMasjidName] — use it for the canonical
  // masjid name so every screen surfaces the same string.
}
