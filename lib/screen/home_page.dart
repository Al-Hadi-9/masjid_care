import 'dart:async';

import 'package:flutter/material.dart';

import 'prayer_time_page.dart';
import 'forbidden_time_page.dart';
import 'islamic_event.dart';
import '../services/prayer_time_service.dart';
import '../services/settings_service.dart';
import '../services/masjid_service.dart';
import '../widgets/app_appbar.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, this.title = ''});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _currentPrayerName = 'ফজর';
  String _currentPrayerTime = '০৫:১৫ AM';
  String _currentPrayerEnd = '০৬:১৮ AM';
  double _progress = 0.0;
  String? _waqtLabel;
  String _remainingTime = '০ মিনিট';
  bool _isForbidden = false;
  bool _isNextPrayer = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadCurrentPrayer();
    _loadJamaatTimes();
    // Countdown text is rounded to whole minutes, so keep the expensive
    // home-page rebuild aligned with that visible update cadence.
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadCurrentPrayer();
    });
    // The four grid cards need to flip between Bangla and English when
    // the user changes the language in Settings. Listening here keeps
    // the home page consistent without forcing the whole app to push
    // a fresh home widget on every change.
    SettingsService.instance.addListener(_onSettingsChanged);
    MasjidService.instance.addListener(_onJamaatTimesChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SettingsService.instance.removeListener(_onSettingsChanged);
    MasjidService.instance.removeListener(_onJamaatTimesChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onJamaatTimesChanged() {
    // The jamaat schedule page subscribes directly to the masjid settings.
  }

  Future<void> _loadJamaatTimes() async {
    await MasjidService.instance.loadJamaatTimes();
  }

  Future<void> _loadCurrentPrayer() async {
    try {
      final timings = await PrayerTimeService.fetchTodayTimings();
      if (!mounted) return;

      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;
      final forbidden = PrayerScheduleBuilder.buildForbiddenTimes(timings);
      final sunriseStart = _todayAt(timings.sunrise);
      final sunriseEnd = _todayAt(
        PrayerScheduleBuilder.addMinutes(timings.sunrise, 15),
      );
      final sunsetStart = _todayAt(
        PrayerScheduleBuilder.addMinutes(timings.maghrib, -5),
      );
      final sunsetEnd = _todayAt(
        PrayerScheduleBuilder.addMinutes(timings.maghrib, 5),
      );
      final nowDateTime = now;

      final ranges = <_PrayerRange>[
        _PrayerRange('fajr', 'ভোর', timings.fajr, timings.sunrise),
        _PrayerRange('dhuhr', 'দুপুর', timings.dhuhr, timings.asr),
        _PrayerRange(
          'asr',
          'বিকেল',
          timings.asr,
          forbidden.sunsetWindow.split(' - ').first,
        ),
        _PrayerRange('maghrib', 'সন্ধ্যা', timings.maghrib, timings.isha),
        _PrayerRange('isha', 'রাত', timings.isha, timings.fajr),
      ];

      _PrayerRange pick = ranges.first;
      int sFinal = 0;
      int eFinal = 0;
      int cmpFinal = 0;
      var forbiddenNow = false;
      var nextPrayer = false;
      DateTime? countdownTarget;
      DateTime? forbiddenStart;
      DateTime? forbiddenEnd;
      String displayName = '';
      String displayStart = '';
      String displayEnd = '';

      if (!nowDateTime.isBefore(sunriseStart) &&
          nowDateTime.isBefore(sunriseEnd)) {
        forbiddenNow = true;
        displayName = _prayerName('forbidden');
        displayStart = PrayerScheduleBuilder.formatTime(timings.sunrise);
        displayEnd = PrayerScheduleBuilder.formatTime(
          PrayerScheduleBuilder.addMinutes(timings.sunrise, 15),
        );
        countdownTarget = sunriseEnd;
        forbiddenStart = sunriseStart;
        forbiddenEnd = sunriseEnd;
      } else if (!nowDateTime.isBefore(sunsetStart) &&
          nowDateTime.isBefore(sunsetEnd)) {
        forbiddenNow = true;
        displayName = _prayerName('forbidden');
        displayStart = PrayerScheduleBuilder.formatTime(
          PrayerScheduleBuilder.addMinutes(timings.maghrib, -5),
        );
        displayEnd = PrayerScheduleBuilder.formatTime(
          PrayerScheduleBuilder.addMinutes(timings.maghrib, 5),
        );
        countdownTarget = sunsetEnd;
        forbiddenStart = sunsetStart;
        forbiddenEnd = sunsetEnd;
      } else if (nowDateTime.isAfter(sunriseEnd) &&
          nowDateTime.isBefore(_todayAt(timings.dhuhr))) {
        nextPrayer = true;
        displayName = _prayerName('dhuhr');
        displayStart = PrayerScheduleBuilder.formatTime(
          PrayerScheduleBuilder.addMinutes(timings.sunrise, 15),
        );
        displayEnd = PrayerScheduleBuilder.formatTime(timings.dhuhr);
        countdownTarget = _todayAt(timings.dhuhr);
      }

      final cur = currentMinutes;
      for (final r in ranges) {
        final s = _toMinutes(r.start);
        final e = _toMinutes(r.end);
        final ishaAfterMidnight = r.name == 'isha' && cur < e;
        final isIsha = r.name == 'isha';
        final isCurrent = isIsha ? cur >= s || cur < e : cur >= s && cur < e;
        if (isCurrent) {
          pick = r;
          sFinal = s;
          eFinal = isIsha ? e + 24 * 60 : e;
          cmpFinal = ishaAfterMidnight ? cur + 24 * 60 : cur;
          break;
        }
      }

      final target = countdownTarget ?? _nextOccurrence(pick.end, nowDateTime);

      // প্রোগ্রেস ক্যালকুলেশন
      double progress = 0.0;
      if (eFinal > sFinal) {
        progress = (cmpFinal - sFinal) / (eFinal - sFinal);
      }
      if (nextPrayer) {
        final nextPrayerStart = sunriseEnd;
        final total = target.difference(nextPrayerStart).inSeconds;
        final elapsed = nowDateTime.difference(nextPrayerStart).inSeconds;
        progress = total <= 0 ? 1 : elapsed / total;
      }
      if (forbiddenNow && forbiddenStart != null && forbiddenEnd != null) {
        final total = forbiddenEnd.difference(forbiddenStart).inSeconds;
        final elapsed = nowDateTime.difference(forbiddenStart).inSeconds;
        progress = total <= 0 ? 1 : elapsed / total;
      }
      final clampedProgress = progress.clamp(0.0, 1.0);
      final remainingSeconds = target
          .difference(nowDateTime)
          .inSeconds
          .clamp(0, 86400);
      final remainingTime = _formatRemainingTime(remainingSeconds);

      setState(() {
        _isForbidden = forbiddenNow;
        _isNextPrayer = nextPrayer;
        _waqtLabel = forbiddenNow
            ? 'নিষিদ্ধ সময়'
            : nextPrayer
            ? 'পরবর্তী ওয়াক্ত'
            : null;
        _currentPrayerName = displayName.isEmpty
            ? _prayerName(pick.name)
            : displayName;
        _currentPrayerTime = displayStart.isEmpty
            ? PrayerScheduleBuilder.formatTime(pick.start)
            : displayStart;
        _currentPrayerEnd = displayEnd.isEmpty
            ? PrayerScheduleBuilder.formatTime(pick.end)
            : displayEnd;
        _progress = clampedProgress;
        _remainingTime = remainingTime;
      });
    } catch (_) {}
  }

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  static DateTime _todayAt(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static DateTime _nextOccurrence(String hhmm, DateTime now) {
    var occurrence = _todayAt(hhmm);
    if (!occurrence.isAfter(now)) {
      occurrence = occurrence.add(const Duration(days: 1));
    }
    return occurrence;
  }

  String _formatRemainingTime(int seconds) {
    final minutes = (seconds / 60).ceil();
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    final parts = <String>[];
    final isBangla = SettingsService.instance.isBangla;
    if (hours > 0) {
      parts.add('${_formatDigits(hours, isBangla)} ${isBangla ? 'ঘণ্টা' : 'hours'}');
    }
    parts.add('${_formatDigits(remainingMinutes, isBangla)} ${isBangla ? 'মিনিট' : 'min'}');
    return parts.join(' ');
  }

  String _formatDigits(int value, bool isBangla) {
    if (!isBangla) return value.toString();
    const digits = '০১২৩৪৫৬৭৮৯';
    return value.toString().split('').map((digit) {
      return digits[int.parse(digit)];
    }).join();
  }

  String _prayerName(String key) {
    final isBangla = SettingsService.instance.isBangla;
    return switch (key) {
      'fajr' => isBangla ? 'ফজর' : 'Fajr',
      'dhuhr' => isBangla ? 'যোহর' : 'Dhuhr',
      'asr' => isBangla ? 'আসর' : 'Asr',
      'maghrib' => isBangla ? 'মাগরিব' : 'Maghrib',
      'isha' => isBangla ? 'এশা' : 'Isha',
      'forbidden' => isBangla ? 'নিষিদ্ধ সময়' : 'Forbidden time',
      'next' => isBangla ? 'পরবর্তী ওয়াক্ত' : 'Next prayer',
      _ => key,
    };
  }

  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mosqueBadgeSize = ((MediaQuery.sizeOf(context).width - 200) * 0.42)
        .clamp(120.0, 180.0);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      body: RepaintBoundary(
        child: SingleChildScrollView(
          key: const PageStorageKey<String>('home_scroll'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Column(
              children: [
                // Hero Waqt & Prayer Card
                Container(
                  width: double.infinity,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 76,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _isForbidden
                                      ? Colors.redAccent.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isForbidden
                                        ? Colors.redAccent.withValues(
                                            alpha: 0.4,
                                          )
                                        : Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isForbidden
                                          ? Icons.warning_amber_rounded
                                          : Icons.access_time_rounded,
                                      color: _isForbidden
                                          ? Colors.white
                                          : const Color(0xFF008000),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _waqtLabel ?? Tr.homeCurrentWaqt(context),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: -10,
                              right: 0,
                              child: Image.asset(
                                'assets/images/icon.png',
                                width: mosqueBadgeSize,
                                height: mosqueBadgeSize,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentPrayerName,
                        style: TextStyle(
                          color: _isForbidden
                              ? const Color(0xFFFF8A80)
                              : Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (!_isNextPrayer) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentPrayerTime,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '—',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Text(
                              _currentPrayerEnd,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      // প্রোগ্রেস বার
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isForbidden
                                ? const Color(0xFFFF5252)
                                : const Color(0xFF008000),
                          ),
                          minHeight: 7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Tr.homeStart(context),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${Tr.homeRemaining(context)}$_remainingTime',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            Tr.homeEnd(context),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.08,
                  children: [
                    _buildMenuCard(
                      Icons.alarm_rounded,
                      Tr.homePrayerTime(context),
                      const Color(0xFFE8F5E9),
                      const Color(0xFF1B5E4E),
                      () => _navigateTo(const PrayerTimePage()),
                    ),
                    _buildMenuCard(
                      Icons.block_rounded,
                      Tr.homeForbiddenTime(context),
                      const Color(0xFFFFEBEE),
                      const Color(0xFFD32F2F),
                      () => _navigateTo(const ForbiddenTimePage()),
                    ),
                    _buildMenuCard(
                      Icons.groups_2_rounded,
                      SettingsService.instance.isBangla
                          ? 'জামাতের সময়'
                          : 'Jamaat Times',
                      const Color(0xFFE8F5E9),
                      const Color(0xFF2E7D32),
                      () => _navigateTo(const JamaatTimePage()),
                    ),
                    _buildMenuCard(
                      Icons.calendar_month_rounded,
                      Tr.homeIslamicEvent(context),
                      const Color(0xFFEDE7F6),
                      const Color(0xFF5E35B1),
                      () => _navigateTo(const IslamicEventPage()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    IconData icon,
    String title,
    Color iconBg,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF3F5F8), Color(0xFFE2E7EC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.45, 1.0],
            ),
            border: Border.all(color: const Color(0xFFCFD8DF), width: 1.3),
            boxShadow: [
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
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, iconBg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 2,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 35)),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrayerRange {
  final String name, period, start, end;
  const _PrayerRange(this.name, this.period, this.start, this.end);
}

class JamaatTimePage extends StatefulWidget {
  const JamaatTimePage({super.key});

  @override
  State<JamaatTimePage> createState() => _JamaatTimePageState();
}

class _JamaatTimePageState extends State<JamaatTimePage> {
  late Map<String, String> _times;
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
    _times = Map.from(MasjidService.instance.jamaatTimes);
    MasjidService.instance.addListener(_onTimesChanged);
    _load();
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

  @override
  Widget build(BuildContext context) {
    SettingsScope.of(context);
    final isBangla = SettingsService.instance.isBangla;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: isBangla ? 'জামাতের সময়সূচী' : 'Jamaat Schedule',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 25,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E4E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isBangla ? 'জামাতের সময়সূচী' : 'Jamaat Schedule',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final prayer in _prayers)
                    _JamaatPrayerCard(
                      name: isBangla ? prayer.$2 : prayer.$3,
                      time: _formatTime(_times[prayer.$1] ?? '05:20'),
                      icon: prayer.$6,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return value;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}

class _JamaatPrayerCard extends StatelessWidget {
  const _JamaatPrayerCard({
    required this.name,
    required this.time,
    required this.icon,
  });
  final String name, time;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8EEF1), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .03),
          blurRadius: 10,
          offset: const Offset(0, 3),
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
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1B5E4E), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF1B5E4E).withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E4E),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
