import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screen/masjid_auth_gate.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/quran_api.dart';
import 'services/prayer_time_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait â€” the layout is not designed for
  // landscape and toggling orientation triggers an expensive relayout.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await initializeApp();

  // Load language / madhhab / location from SharedPreferences before
  // the first frame so the bottom-nav and item-card labels match the
  // user's persisted choice on cold launch.
  await SettingsService.instance.hydrate();

  // Pre-warm the on-disk caches before the first frame so that if the
  // user opens the Quran page (or any tab that reads prayer times)
  // while offline, the UI does not flash an error. Each hydration is
  // independently guarded against failure so a corrupt prefs file on
  // one feature cannot break the other.
  // ignore: discarded_futures
  _warmCaches();

  runApp(const MyApp());
}

/// Best-effort cache hydration. Failures are swallowed because a missing
/// or corrupt cache just means the user will fall back to the network
/// (or get a friendly error if they're offline too).
Future<void> initializeApp() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> _warmCaches() async {
  try {
    await QuranApi.hydrateFromDisk();
  } catch (_) {
    /* ignore */
  }
  try {
    // Touching the service loads any cached timings into its static
    // in-memory cache. We deliberately do NOT kick off a network call
    // here — that happens lazily on the first UI consumer.
    await PrayerTimeService.fetchTodayTimings();
  } catch (_) {
    /* ignore */
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Static, pre-built theme avoids the per-launch ColorScheme.fromSeed
    // expansion that adds noticeable startup latency on low-end devices.
    //
    // `SettingsScope` is the InheritedNotifier that powers `Tr.*`
    // lookups all over the app. It MUST be an ancestor of every widget
    // that calls `Tr.*` (which is the bottom nav, the home page item
    // cards, the drawer, the settings page). Wrapping it around the
    // `MaterialApp.home` is the simplest spot — every screen in the
    // app is mounted under `AppShell`, so they all see the scope.
    return SettingsScope(
      service: SettingsService.instance,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Masjid Care',
        theme: _appTheme,
        home: const MasjidAuthGate(),
      ),
    );
  }
}

// Hand-tuned Material 3 colour scheme. Built once at compile time so the
// first frame renders without going through ColorScheme.fromSeed which is
// the main cause of the slow app-launch on cold start.
const ColorScheme _kScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1B5E4E),
  onPrimary: Colors.white,
  secondary: Color(0xFF009688),
  onSecondary: Colors.white,
  error: Color(0xFFB00020),
  onError: Colors.white,
  surface: Colors.white,
  onSurface: Color(0xFF202124),
);

final ThemeData _appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Noto Sans Bengali',
  colorScheme: _kScheme,
  scaffoldBackgroundColor: const Color(0xFFF6F8F9),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE8EEF1), width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDCE3E6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDCE3E6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1B5E4E), width: 1.6),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1B5E4E),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1B5E4E),
    foregroundColor: Colors.white,
    iconTheme: IconThemeData(color: Colors.white),
    // toolbarHeight is intentionally NOT set here — AppAppBar is a
    // PreferredSizeWidget that picks its own height based on whether a
    // subtitle is rendered. Pinning a fixed toolbarHeight in the theme
    // would clip the two-line title on screens like Hadith / Events.
    elevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
  ),
);
