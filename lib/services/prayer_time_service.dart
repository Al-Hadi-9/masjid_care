import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_service.dart';

class PrayerWindow {
  final String name, period, start, end;
  const PrayerWindow({
    required this.name,
    required this.period,
    required this.start,
    required this.end,
  });
}

class PrayerTimes {
  final String fajr, sunrise, dhuhr, asr, maghrib, isha;
  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    final timings = json['data']['timings'] as Map<String, dynamic>;
    String normalize(String value) => value.split(' ').first;
    return PrayerTimes(
      fajr: normalize(timings['Fajr'] ?? ''),
      sunrise: normalize(timings['Sunrise'] ?? ''),
      dhuhr: normalize(timings['Dhuhr'] ?? ''),
      asr: normalize(timings['Asr'] ?? ''),
      maghrib: normalize(timings['Maghrib'] ?? ''),
      isha: normalize(timings['Isha'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'fajr': fajr,
    'sunrise': sunrise,
    'dhuhr': dhuhr,
    'asr': asr,
    'maghrib': maghrib,
    'isha': isha,
  };

  factory PrayerTimes.fromStoredJson(Map<String, dynamic> json) {
    return PrayerTimes(
      fajr: json['fajr'] ?? '',
      sunrise: json['sunrise'] ?? '',
      dhuhr: json['dhuhr'] ?? '',
      asr: json['asr'] ?? '',
      maghrib: json['maghrib'] ?? '',
      isha: json['isha'] ?? '',
    );
  }
}

class PrayerTimeService {
  // Defaults retained for the fallback path and as the initial values
  // before SettingsService has hydrated. The actual values sent to
  // aladhan are pulled from SettingsService on every fetch.
  static const String _defaultCity = 'Debidwar';
  static const String _defaultCountry = 'Bangladesh';
  static const String _cacheIndexKey = 'prayer_time_cache_index',
      _cacheEntryPrefix = 'prayer_time_cache_';
  static const int _retentionDays = 60;

  static PrayerTimes? _cache;
  static DateTime? _cachedOn;
  // The (city, country, method) tuple that produced the current cache.
  // When the user changes any of these in Settings we must drop the
  // cache so the next fetch uses the new value instead of returning
  // a stale result for the previous location/madhhab.
  static String? _cachedCity;
  static String? _cachedCountry;
  static int? _cachedMethod;
  static Future<PrayerTimes>? _inflight;

  // ── Settings accessors ───────────────────────────────────────────
  //
  // Centralised here so the rest of the class never has to import
  // SettingsService directly. If we ever stop using SettingsService
  // we just swap these getters.
  static String get _city => SettingsService.instance.city.isEmpty
      ? _defaultCity
      : SettingsService.instance.city;
  static String get _country => SettingsService.instance.country.isEmpty
      ? _defaultCountry
      : SettingsService.instance.country;
  static int get _method => SettingsService.instance.madhhab.apiMethod;

  /// Invalidate the in-memory cache. Call this from the Settings page
  /// (or anywhere else) after the user changes location or madhhab so
  /// the next `fetchTodayTimings()` re-hits the network with the new
  /// parameters instead of returning a stale entry.
  ///
  /// This intentionally only drops the in-memory cache — the on-disk
  /// cache (see `_saveBatchToPrefs`/`_safeReadFromPrefs`) is keyed by
  /// date only. That's fine because the on-disk data is only used as
  /// a same-day fallback when the network is unreachable; on a fresh
  /// fetch the network result (which respects the current settings)
  /// wins.
  static void invalidate() {
    _cache = null;
    _cachedOn = null;
    _cachedCity = null;
    _cachedCountry = null;
    _cachedMethod = null;
    _inflight = null;
  }

  static Future<PrayerTimes> fetchTodayTimings() async {
    final now = DateTime.now();
    final dayKey = DateTime(now.year, now.month, now.day);
    // Drop the cache if settings changed underneath us.
    if (_cache != null &&
        (_cachedCity != _city ||
            _cachedCountry != _country ||
            _cachedMethod != _method)) {
      _cache = null;
      _cachedOn = null;
    }
    if (_cache != null && _cachedOn == dayKey) return _cache!;
    if (_inflight != null) return _inflight!;

    final completer = _inflight = _fetchOrFallback(dayKey);
    try {
      final result = await completer;
      _cache = result;
      _cachedOn = dayKey;
      _cachedCity = _city;
      _cachedCountry = _country;
      _cachedMethod = _method;
      return result;
    } finally {
      _inflight = null;
    }
  }

  // এই মেথডটি এরর দূর করার জন্য অপরিহার্য
  static PrayerTimes fallbackTimings() {
    return _defaultTimings();
  }

  static Future<PrayerTimes> _fetchOrFallback(DateTime dayKey) async {
    final cached = await _safeReadFromPrefs(targetDate: dayKey);
    if (cached != null) {
      _cache = cached;
      _cachedOn = dayKey;
      _refreshInBackground();
      return cached;
    }
    try {
      return await _fetchFromNetwork();
    } catch (_) {
      return fallbackTimings();
    }
  }

  static Future<void> _refreshInBackground() async {
    try {
      await _fetchFromNetwork();
    } catch (_) {}
  }

  static PrayerTimes _defaultTimings() => PrayerTimes(
    fajr: '05:15',
    sunrise: '06:18',
    dhuhr: '12:00',
    asr: '15:30',
    maghrib: '18:00',
    isha: '19:30',
  );

  static Future<PrayerTimes> _fetchFromNetwork() async {
    final now = DateTime.now();
    final Map<DateTime, PrayerTimes> batch = {};
    await _fetchMonthInto(now.year, now.month, batch);
    final next = now.add(const Duration(days: 30));
    if (next.month != now.month) {
      await _fetchMonthInto(next.year, next.month, batch);
    }
    if (batch.isNotEmpty) await _saveBatchToPrefs(batch);
    final todayKey = DateTime(now.year, now.month, now.day);
    return batch[todayKey] ??
        (await _safeReadFromPrefs(targetDate: now) ?? fallbackTimings());
  }

  static Future<void> _fetchMonthInto(
    int year,
    int month,
    Map<DateTime, PrayerTimes> batch,
  ) async {
    // Pick up the live city/country/method on every call — these read
    // from SettingsService.instance each time, so the moment the user
    // updates a setting the next fetch uses the new value.
    final uri = Uri.parse(
      'https://api.aladhan.com/v1/calendarByCity/$year/$month'
      '?city=$_city&country=$_country&method=$_method',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        for (final dayData in body['data']) {
          final timings = PrayerTimes.fromJson({'data': dayData});
          final dateStr = dayData['date']['gregorian']['date'];
          final parts = dateStr.split('-');
          final dateObj = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
          batch[dateObj] = timings;
        }
      }
    } catch (_) {}
  }

  static Future<void> _saveBatchToPrefs(
    Map<DateTime, PrayerTimes> batch,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_cacheIndexKey) ?? <String>[];
    final today = DateTime.now();
    final yesterday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));

    for (final entry in batch.entries) {
      final stamp = _dateKey(entry.key);
      await prefs.setString(
        _cacheEntryPrefix + stamp,
        jsonEncode(entry.value.toJson()),
      );
      if (!index.contains(stamp)) index.add(stamp);
    }

    index.removeWhere((stamp) {
      try {
        final parts = stamp.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        if (date.isBefore(yesterday)) {
          prefs.remove(_cacheEntryPrefix + stamp);
          return true;
        }
      } catch (_) {}
      return false;
    });

    index.sort();
    while (index.length > _retentionDays) {
      final oldest = index.removeAt(0);
      prefs.remove(_cacheEntryPrefix + oldest);
    }
    await prefs.setStringList(_cacheIndexKey, index);
  }

  static Future<PrayerTimes?> _safeReadFromPrefs({DateTime? targetDate}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (targetDate != null) {
        final raw = prefs.getString(_cacheEntryPrefix + _dateKey(targetDate));
        if (raw != null) return PrayerTimes.fromStoredJson(jsonDecode(raw));
      }
      final index = prefs.getStringList(_cacheIndexKey) ?? <String>[];
      if (index.isEmpty) return null;
      for (var i = index.length - 1; i >= 0; i--) {
        final raw = prefs.getString(_cacheEntryPrefix + index[i]);
        if (raw != null) return PrayerTimes.fromStoredJson(jsonDecode(raw));
      }
    } catch (_) {}
    return null;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<PrayerTimes> refresh() async {
    _cache = null;
    _cachedOn = null;
    return fetchTodayTimings();
  }
}

class ForbiddenTimes {
  final String sunriseWindow, middayWindow, sunsetWindow;
  ForbiddenTimes({
    required this.sunriseWindow,
    required this.middayWindow,
    required this.sunsetWindow,
  });
}

class PrayerScheduleBuilder {
  static List<PrayerWindow> buildWindows(PrayerTimes t) {
    final forbidden = buildForbiddenTimes(t);
    return [
      PrayerWindow(name: 'fajr', period: '', start: t.fajr, end: t.sunrise),
      PrayerWindow(name: 'dhuhr', period: '', start: t.dhuhr, end: t.asr),
      PrayerWindow(
        name: 'asr',
        period: '',
        start: t.asr,
        end: forbidden.sunsetWindow.split(' - ').first,
      ),
      PrayerWindow(
        name: 'maghrib',
        period: '',
        start: t.maghrib,
        end: t.isha,
      ),
      PrayerWindow(name: 'isha', period: '', start: t.isha, end: t.fajr),
    ];
  }

  static ForbiddenTimes buildForbiddenTimes(PrayerTimes t) {
    final sunriseEnd = _addMinutes(t.sunrise, 15);
    final middayStart = _addMinutes(t.dhuhr, -4),
        middayEnd = _addMinutes(t.dhuhr, 4);
    final sunsetStart = _addMinutes(t.maghrib, -5),
        sunsetEnd = _addMinutes(t.maghrib, 5);
    return ForbiddenTimes(
      sunriseWindow: '${t.sunrise} - $sunriseEnd',
      middayWindow: '$middayStart - $middayEnd',
      sunsetWindow: '$sunsetStart - $sunsetEnd',
    );
  }

  static String _addMinutes(String hhmm, int minutes) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final total =
        (int.tryParse(parts[0]) ?? 0) * 60 +
        (int.tryParse(parts[1]) ?? 0) +
        minutes;
    return '${((total ~/ 60) % 24).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  static String addMinutes(String hhmm, int minutes) =>
      _addMinutes(hhmm, minutes);

  static String _format(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0, m = int.tryParse(parts[1]) ?? 0;
    return '${(h % 12 == 0 ? 12 : h % 12).toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
  }

  static String formatTime(String hhmm) => _format(hhmm);
  static String formatRange(String range24) {
    final parts = range24.split('-');
    return parts.length != 2
        ? range24
        : '${_format(parts[0].trim())} - ${_format(parts[1].trim())}';
  }
}
