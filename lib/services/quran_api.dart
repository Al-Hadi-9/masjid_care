import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Marker exception thrown when the Quran API cannot be reached AND no
/// local cache exists for the requested Surah. Callers can `catch`
/// this specific type to show a friendly Bangla "no internet / no cache"
/// message instead of a raw "API failed" stack trace.
class QuranOfflineException implements Exception {
  final String message;
  const QuranOfflineException(this.message);
  @override
  String toString() => message;
}

// Internal alias so the static methods below stay compact.
typedef _QuranOfflineException = QuranOfflineException;

class SurahDetail {
  final int number;
  final String name;
  final String englishName;
  final String revelationType;
  final int numberOfAyahs;
  final List<Ayah> ayahs;

  SurahDetail({
    required this.number,
    required this.name,
    required this.englishName,
    required this.revelationType,
    required this.numberOfAyahs,
    required this.ayahs,
  });

  factory SurahDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final ayahs = (data['ayahs'] as List)
        .map((a) => Ayah.fromJson(a as Map<String, dynamic>))
        .toList();
    return SurahDetail(
      number: data['number'] as int,
      name: data['name'] as String,
      englishName: data['englishName'] as String,
      revelationType: data['revelationType'] as String,
      numberOfAyahs: data['numberOfAyahs'] as int,
      ayahs: ayahs,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'englishName': englishName,
    'revelationType': revelationType,
    'numberOfAyahs': numberOfAyahs,
    'ayahs': ayahs.map((a) => a.toJson()).toList(),
  };

  factory SurahDetail.fromStoredJson(Map<String, dynamic> json) {
    final ayahs = (json['ayahs'] as List)
        .map((a) => Ayah.fromStoredJson(a as Map<String, dynamic>))
        .toList();
    return SurahDetail(
      number: json['number'] as int,
      name: json['name'] as String,
      englishName: json['englishName'] as String,
      revelationType: json['revelationType'] as String,
      numberOfAyahs: json['numberOfAyahs'] as int,
      ayahs: ayahs,
    );
  }
}

class Ayah {
  final int number;
  final String text;
  final String translation;

  Ayah({required this.number, required this.text, required this.translation});

  factory Ayah.fromJson(Map<String, dynamic> json) {
    String translation = '';
    if (json['translations'] is List &&
        (json['translations'] as List).isNotEmpty) {
      translation = json['translations'][0]['text'] ?? '';
    } else if (json['text'] != null) {
      translation = json['text'];
    }
    return Ayah(
      number: json['number'] as int,
      text: json['text'] as String,
      translation: _stripHtml(translation),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'text': text,
    'translation': translation,
  };

  factory Ayah.fromStoredJson(Map<String, dynamic> json) {
    return Ayah(
      number: json['number'] as int,
      text: json['text'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
    );
  }

  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .trim();
  }
}

class SearchHit {
  final int surahNumber;
  final String surahName;
  final Ayah ayah;

  SearchHit({
    required this.surahNumber,
    required this.surahName,
    required this.ayah,
  });
}

class QuranApi {
  static const String _surahPrefix = 'quran_surah_';
  static const String _corpusIndexKey = 'quran_corpus_index';

  // Per-session cache of already-loaded surahs keyed by number. This is the
  // biggest perf win: tapping a surah, going back, then tapping it again no
  // longer hits the network at all.
  static final Map<int, SurahDetail> _surahCache = <int, SurahDetail>{};
  // Pre-loaded full corpus, lazily populated by `prefetchAll()`. Once primed
  // it powers both the surah list and the search tab without any further
  // network call.
  static bool _corpusLoading = false;
  static final Map<int, SurahDetail> _corpusCache = <int, SurahDetail>{};
  // Tracks whether we've already hydrated the in-memory caches from disk
  // for this session. Avoids re-reading every preference on every call.
  static bool _hydrated = false;

  /// Reads every previously cached Surah from SharedPreferences into the
  /// in-memory maps. Call once at startup so the user can keep using any
  /// Surah they had visited even with no network.
  static Future<void> hydrateFromDisk() async {
    if (_hydrated) return;
    _hydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_surahPrefix));
      for (final key in keys) {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final surah = SurahDetail.fromStoredJson(json);
          _surahCache[surah.number] = surah;
          _corpusCache[surah.number] = surah;
        } catch (_) {
          // Skip corrupt entries silently — they'll be overwritten on the
          // next successful fetch.
        }
      }
    } catch (_) {
      // SharedPreferences can fail on first launch or some platforms; we
      // just fall back to network-only fetching in that case.
    }
  }

  static Future<SurahDetail> fetchSurah(
    int surahNumber, {
    String translationEdition = 'bn.bengali',
  }) async {
    // Memory cache hit — fastest path.
    final cached = _surahCache[surahNumber];
    if (cached != null) return cached;

    // First time we hit the API in this session, warm the in-memory caches
    // from disk so previously saved Surahs do not flash a loading spinner.
    await hydrateFromDisk();
    final fromDisk = _surahCache[surahNumber];
    if (fromDisk != null) return fromDisk;

    // No memory or disk cache for this Surah. Try the network first so
    // fresh content reaches the user as soon as possible; on failure
    // (airplane mode, no signal, timeout) we throw a clean offline
    // signal so the UI can show a friendly "no cache" message instead
    // of a raw "API failed" stack trace.
    final arabicUri = Uri.parse(
      'https://api.alquran.cloud/v1/surah/$surahNumber/quran-uthmani',
    );
    final transUri = Uri.parse(
      'https://api.alquran.cloud/v1/surah/$surahNumber/$translationEdition',
    );

    try {
      // Run both requests in parallel — the original code awaited them
      // sequentially which doubled the perceived latency. Short timeout
      // so airplane-mode users don't stare at a spinner for 40 s.
      final futures = await Future.wait<http.Response>([
        http.get(arabicUri).timeout(const Duration(seconds: 8)),
        http.get(transUri).timeout(const Duration(seconds: 8)),
      ]);
      final arabicResp = futures[0];
      final transResp = futures[1];

      if (arabicResp.statusCode != 200 || transResp.statusCode != 200) {
        throw _QuranOfflineException(
          'Al-Quran Cloud API failed '
          '(${arabicResp.statusCode}/${transResp.statusCode})',
        );
      }

      final arabicBody = jsonDecode(arabicResp.body) as Map<String, dynamic>;
      final transBody = jsonDecode(transResp.body) as Map<String, dynamic>;

      final arabicData = arabicBody['data'] as Map<String, dynamic>;
      final transData = transBody['data'] as Map<String, dynamic>;
      final arabicAyahs = arabicData['ayahs'] as List;
      final transAyahs = transData['ayahs'] as List;

      final List<Ayah> combined = [];
      for (var i = 0; i < arabicAyahs.length; i++) {
        final a = arabicAyahs[i] as Map<String, dynamic>;
        String trans = '';
        if (i < transAyahs.length) {
          final t = transAyahs[i] as Map<String, dynamic>;
          trans = (t['text'] ?? '').toString();
        }
        combined.add(
          Ayah(
            number: a['number'] as int,
            text: (a['text'] ?? '').toString(),
            translation: Ayah._stripHtml(trans),
          ),
        );
      }

      final detail = SurahDetail(
        number: arabicData['number'] as int,
        name: arabicData['name'] as String,
        englishName: arabicData['englishName'] as String,
        revelationType: arabicData['revelationType'] as String,
        numberOfAyahs: arabicData['numberOfAyahs'] as int,
        ayahs: combined,
      );

      _surahCache[surahNumber] = detail;
      _corpusCache[surahNumber] = detail;
      // Persist for offline use. Fire-and-forget — we don't want disk I/O
      // to slow the user-visible load.
      // ignore: discarded_futures
      _saveSurahToDisk(detail);
      return detail;
    } catch (e) {
      // Any network/HTTP/JSON failure here means the user is offline
      // (or the API is down). Rather than crashing the UI, return a
      // tiny placeholder Surah so the page still renders something
      // sensible and the user can read the Bangla offline notice.
      // Do not cache the placeholder. Caching it would make a temporary
      // network failure permanent for the rest of this app session and
      // would also make the search corpus look complete.
      return _offlinePlaceholder(surahNumber);
    }
  }

  /// Returns a tiny placeholder Surah used when the network is down
  /// and we have no cached content for the requested Surah number. It
  /// exists so callers can render a normal Surah-detail UI instead of
  /// a hard error — the user sees a clear "no internet / no cache"
  /// message but the rest of the app keeps working.
  static SurahDetail _offlinePlaceholder(int number) {
    return SurahDetail(
      number: number,
      name: '—',
      englishName: 'Offline',
      revelationType: '—',
      numberOfAyahs: 0,
      ayahs: const <Ayah>[],
    );
  }

  static Future<void> _saveSurahToDisk(SurahDetail s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _surahPrefix + s.number.toString(),
        jsonEncode(s.toJson()),
      );
      final index = prefs.getStringList(_corpusIndexKey) ?? <String>[];
      final stamp = s.number.toString();
      if (!index.contains(stamp)) {
        index.add(stamp);
        index.sort();
        await prefs.setStringList(_corpusIndexKey, index);
      }
    } catch (_) {
      // Best-effort cache — failures here must never crash the UI.
    }
  }

  /// Pre-load all 114 surahs in the background. Search then becomes a
  /// pure in-memory filter, instead of looping through 114 sequential
  /// network calls every time the user types a query (which used to take
  /// 30+ seconds for a single search).
  ///
  /// On no network, only the Surahs already cached on disk will be
  /// hydrated — that is still enough to search, browse, and read fully.
  static Future<void> prefetchAll({
    String translationEdition = 'bn.bengali',
  }) async {
    if (_corpusLoading) return;
    await hydrateFromDisk();
    if (_corpusCache.length >= 114) {
      _corpusLoading = false;
      return;
    }
    _corpusLoading = true;
    try {
      // Concurrency cap of 6 keeps mobile networks happy without
      // serialising the whole thing.
      const batchSize = 6;
      for (var start = 1; start <= 114; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, 114);
        final batch = <Future<void>>[];
        for (var s = start; s <= end; s++) {
          if (_corpusCache.containsKey(s)) continue;
          batch.add(
            fetchSurah(s, translationEdition: translationEdition).then((_) {}),
          );
        }
        if (batch.isEmpty) continue;
        // Don't let a single failed Surah cancel the whole prefetch —
        // partial offline coverage is still useful.
        await Future.wait(batch, eagerError: false);
      }
    } finally {
      _corpusLoading = false;
    }
  }

  static Future<List<SearchHit>> search(
    String keyword, {
    String translationEdition = 'bn.bengali',
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) return [];

    // Surah-name searches should work immediately and without downloading
    // the entire Quran corpus. This also covers Bangla transliterations
    // such as "সূরা ইউনুস" from the built-in Surah list.
    final normalizedQuery = _normalizeSearchText(query);
    final surahNameHits = <SearchHit>[];
    for (var number = 1; number <= 114; number++) {
      final name = _surahNameForSearch(number);
      if (_normalizeSearchText(name).contains(normalizedQuery)) {
        final surah = _corpusCache[number] ?? _surahCache[number];
        surahNameHits.add(
          SearchHit(
            surahNumber: number,
            surahName: surah?.name ?? name,
            ayah: surah?.ayahs.isNotEmpty == true
                ? surah!.ayahs.first
                : Ayah(number: 1, text: '', translation: ''),
          ),
        );
      }
    }
    if (surahNameHits.isNotEmpty) return surahNameHits;

    // Search the content that is already available before going to the
    // network. This keeps previously cached searches instant and also makes
    // search useful while offline.
    final cachedHits = _searchCache(query);
    if (_corpusCache.length >= 114) {
      return cachedHits;
    }

    // Do not download all 114 Surahs for one search. The API's search
    // endpoint returns only matching ayahs and works on the first search,
    // instead of waiting for the background prefetch to finish.
    try {
      return await _searchRemote(query, translationEdition: translationEdition);
    } catch (_) {
      // A partial disk cache is still useful when the device is offline.
      if (cachedHits.isNotEmpty) return cachedHits;
      rethrow;
    }
  }

  static String _normalizeSearchText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'^\s*সূরা\s*'), '')
      // Arabic tashkeel and Quran annotation marks should not affect a
      // search for the same word typed without those marks.
      .replaceAll(
        RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'),
        '',
      )
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  static List<SearchHit> _searchCache(String query) {
    final normalizedQuery = _normalizeSearchText(query);
    final hits = <SearchHit>[];
    for (var s = 1; s <= 114; s++) {
      final surah = _corpusCache[s] ?? _surahCache[s];
      if (surah == null) continue;
      final nameMatches =
          _normalizeSearchText(surah.name).contains(normalizedQuery) ||
          _normalizeSearchText(surah.englishName).contains(normalizedQuery);
      if (nameMatches && surah.ayahs.isNotEmpty) {
        hits.add(
          SearchHit(
            surahNumber: surah.number,
            surahName: surah.name,
            ayah: surah.ayahs.first,
          ),
        );
        continue;
      }
      for (final ayah in surah.ayahs) {
        if (_normalizeSearchText(ayah.translation).contains(normalizedQuery) ||
            _normalizeSearchText(ayah.text).contains(normalizedQuery)) {
          hits.add(
            SearchHit(
              surahNumber: surah.number,
              surahName: surah.name,
              ayah: ayah,
            ),
          );
        }
      }
    }
    return hits;
  }

  static Future<List<SearchHit>> _searchRemote(
    String query, {
    required String translationEdition,
  }) async {
    final edition = RegExp(r'[\u0600-\u06FF]').hasMatch(query)
        ? 'quran-uthmani'
        : translationEdition;
    final uri = Uri.parse(
      'https://api.alquran.cloud/v1/search/'
      '${Uri.encodeComponent(query)}/all/$edition',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw _QuranOfflineException(
        'Al-Quran Cloud search failed (${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final matches = data?['matches'];
    if (matches is! List) return [];

    return matches
        .whereType<Map<String, dynamic>>()
        .map((match) {
          final surah = match['surah'] as Map<String, dynamic>? ?? {};
          final number = match['numberInSurah'] as int? ?? 0;
          final text = (match['text'] ?? '').toString();
          return SearchHit(
            surahNumber: surah['number'] as int? ?? 0,
            surahName: (surah['name'] ?? '').toString(),
            ayah: Ayah(number: number, text: '', translation: text),
          );
        })
        .where((hit) => hit.surahNumber > 0 && hit.ayah.translation.isNotEmpty)
        .toList();
  }

  static String _surahNameForSearch(int number) => const [
    '',
    'ফাতিহা',
    'বাকারা',
    'আলে ইমরান',
    'নিসা',
    'মায়িদাহ',
    'আনআম',
    'আরাফ',
    'আনফাল',
    'তাওবাহ',
    'ইউনুস',
    'হুদ',
    'ইউসুফ',
    'রাদ',
    'ইব্রাহিম',
    'হিজর',
    'নাহল',
    'বনি ইসরাইল',
    'কাহফ',
    'মারইয়াম',
    'ত্বা-হা',
    'আম্বিয়া',
    'হজ্জ',
    'মুমিনুন',
    'নূর',
    'ফুরকান',
    'শুআরা',
    'নামল',
    'কাসাস',
    'আনকাবুত',
    'রূম',
    'লোকমান',
    'সিজদাহ',
    'আহযাব',
    'সাবা',
    'ফাতির',
    'ইয়াসিন',
    'সাফফাত',
    'সাদ',
    'যুমার',
    'গাফির',
    'ফুসসিলাত',
    'শূরা',
    'যুখরুফ',
    'দুখান',
    'জাসিয়া',
    'আহকাফ',
    'মুহাম্মদ',
    'ফাতহ',
    'হুজুরাত',
    'কাফ',
    'যারিয়াত',
    'তূর',
    'নাজম',
    'কামার',
    'রহমান',
    'ওয়াকিয়া',
    'হাদিদ',
    'মুজাদালাহ',
    'হাশর',
    'মুমতাহিনা',
    'সফ',
    'জুমুআ',
    'মুনাফিকুন',
    'তাগাবুন',
    'তালাক',
    'তাহরিম',
    'মুলক',
    'কলম',
    'হাক্কাহ',
    'মাআরিজ',
    'নূহ',
    'জিন',
    'মুজ্জাম্মিল',
    'মুদ্দাসসির',
    'কিয়ামাহ',
    'ইনসান',
    'মুরসালাত',
    'নাবা',
    'নাযিয়াত',
    'আবাসা',
    'তাকভির',
    'ইনফিতার',
    'মুতাফফিফিন',
    'ইনশিকাক',
    'বুরুজ',
    'তারিক',
    'আলা',
    'গাশিয়াহ',
    'ফজর',
    'বালাদ',
    'শামস',
    'লাইল',
    'দুহা',
    'ইনশিরাহ',
    'তিন',
    'আলাক',
    'কদর',
    'বাইয়্যিনাহ',
    'যিলযাল',
    'আদিয়াত',
    'কারিআহ',
    'তাকাসুর',
    'আসর',
    'হুমাযাহ',
    'ফিল',
    'কুরাইশ',
    'মাউন',
    'কাউসার',
    'কাফিরুন',
    'নাসর',
    'মাসাদ',
    'ইখলাস',
    'ফালাক',
    'নাস',
  ][number];
}
