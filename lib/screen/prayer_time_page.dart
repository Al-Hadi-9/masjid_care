import 'package:flutter/material.dart';
import '../services/prayer_time_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

class PrayerTimePage extends StatefulWidget {
  const PrayerTimePage({super.key});

  @override
  State<PrayerTimePage> createState() => _PrayerTimePageState();
}

class _PrayerTimePageState extends State<PrayerTimePage> {
  List<PrayerWindow> _windows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTimings();
  }

  Future<void> _loadTimings() async {
    try {
      final timings = await PrayerTimeService.fetchTodayTimings();
      if (!mounted) return;
      setState(() {
        _windows = PrayerScheduleBuilder.buildWindows(timings);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Safe fallback in case of service failure
        _windows = PrayerScheduleBuilder.buildWindows(
          PrayerTimeService.fallbackTimings(),
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to language toggle so the page header flips with the user setting.
    SettingsScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F7),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _loading = true);
              _loadTimings();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadTimings,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final w in _windows)
                      _buildPrayerCard(
                        name: _prayerName(w.name),
                        start: PrayerScheduleBuilder.formatTime(w.start),
                        end: PrayerScheduleBuilder.formatTime(w.end),
                        icon: _iconFor(w.name),
                        isActive: _isCurrentWindow(w),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E4E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            Tr.prayerScheduleTitle(context),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    return switch (name) {
      'fajr' => Icons.wb_twilight_rounded,
      'dhuhr' => Icons.wb_sunny_rounded,
      'asr' => Icons.wb_cloudy_rounded,
      'maghrib' => Icons.nightlight_round,
      'isha' => Icons.dark_mode_rounded,
      _ => Icons.access_time_rounded,
    };
  }

  String _prayerName(String key) {
    final isBangla = SettingsService.instance.isBangla;
    return switch (key) {
      'fajr' => isBangla ? 'ফজর' : 'Fajr',
      'dhuhr' => isBangla ? 'যোহর' : 'Dhuhr',
      'asr' => isBangla ? 'আসর' : 'Asr',
      'maghrib' => isBangla ? 'মাগরিব' : 'Maghrib',
      'isha' => isBangla ? 'এশা' : 'Isha',
      _ => key,
    };
  }

  bool _isCurrentWindow(PrayerWindow w) {
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    final s = _toMinutes(w.start);
    final e = _toMinutes(w.end);
    final cmp = cur < 6 * 60 ? cur + 24 * 60 : cur;
    final se = e < s ? e + 24 * 60 : e;
    return cmp >= s && cmp < se;
  }

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  Widget _buildPrayerCard({
    required String name,
    required String start,
    required String end,
    required IconData icon,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF0F4538), Color(0xFF1B5E4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFF008000).withValues(alpha: 0.6)
              : const Color(0xFFE8EEF1),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0xFF1B5E4E).withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isActive ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF008000) : const Color(0xFF1B5E4E),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF008000),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            SettingsService.instance.isBangla
                                ? 'চলমান'
                                : 'Current',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.14)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                '$start - $end',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
