import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';
import '../services/masjid_service.dart';
import 'app_shell.dart';
import 'masjid_login_page.dart';

class MasjidAuthGate extends StatefulWidget {
  const MasjidAuthGate({super.key});

  @override
  State<MasjidAuthGate> createState() => _MasjidAuthGateState();
}

class _MasjidAuthGateState extends State<MasjidAuthGate> {
  static const _legacyGoogleCreateDraftKey = 'pending_google_masjid_creation';
  late Future<void> _load;
  bool _rolloverStarted = false;

  @override
  void initState() {
    super.initState();
    _load = _hydrateMasjid();
  }

  Future<void> _hydrateMasjid() async {
    // Remove a form draft left by the previous web redirect flow. Web now
    // completes Google sign-in in a popup, so this draft must not trigger a
    // stale redirect-result lookup on app startup.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyGoogleCreateDraftKey);
    await MasjidService.instance.hydrate();
    if (!MasjidService.instance.hasActiveMasjid) return;
    // Render from the locally cached masjid profile first. Firestore may
    // queue writes while offline, so collection setup must not block startup.
    unawaited(_ensureDatabaseCollections());
  }

  Future<void> _ensureDatabaseCollections() async {
    try {
      await FirestoreService()
          .ensureDatabaseCollections()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // The app can still open offline; Firestore retries when connected.
    }
  }

  Future<void> _ensureYearlyRollover() async {
    try {
      await FirestoreService().getYearlyFinanceSummaries();
    } catch (_) {
      // The financial pages can retry if the connection is temporarily down.
    }
  }

  void _scheduleYearlyRollover() {
    if (_rolloverStarted) return;
    _rolloverStarted = true;
    // Let the first app frame render before making optional finance requests.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureYearlyRollover());
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Google sign-in or masjid creation failed: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _load = _hydrateMasjid()),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!MasjidService.instance.hasActiveMasjid) {
          return const MasjidLoginPage();
        }
        _scheduleYearlyRollover();
        return const AppShell();
      },
    );
  }
}
