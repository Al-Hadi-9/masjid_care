import 'package:flutter/material.dart';
import '../services/quran_api.dart';
import '../services/quran_audio_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;
  bool _loadingSurah = false;
  List<SearchHit> _searchResults = [];
  SurahDetail? _selectedSurah;
  int? _prioritizedSurahNumber;
  // True when the currently opened Surah is the offline placeholder
  // (i.e. the network call failed and we had nothing cached). Used to
  // render an in-page Bangla notice instead of an empty Surah reader.
  bool _surahOfflineNotice = false;
  int _surahTab = 0; // 0 = surah, 1 = search

  static const List<Map<String, String>> _surahList = [
    {"num": "1", "ar": "الفاتحة", "en": "সূরা ফাতিহা"},
    {"num": "2", "ar": "البقرة", "en": "সূরা বাকারা"},
    {"num": "3", "ar": "آل عمران", "en": "সূরা আলে ইমরান"},
    {"num": "4", "ar": "النساء", "en": "সূরা নিসা"},
    {"num": "5", "ar": "المائدة", "en": "সূরা মায়িদাহ"},
    {"num": "6", "ar": "الأنعام", "en": "সূরা আনআম"},
    {"num": "7", "ar": "الأعراف", "en": "সূরা আরাফ"},
    {"num": "8", "ar": "الأنفال", "en": "সূরা আনফাল"},
    {"num": "9", "ar": "التوبة", "en": "সূরা তাওবাহ"},
    {"num": "10", "ar": "يونس", "en": "সূরা ইউনুস"},
    {"num": "11", "ar": "هود", "en": "সূরা হুদ"},
    {"num": "12", "ar": "يوسف", "en": "সূরা ইউসুফ"},
    {"num": "13", "ar": "الرعد", "en": "সূরা রাদ"},
    {"num": "14", "ar": "ابراهيم", "en": "সূরা ইবরাহীম"},
    {"num": "15", "ar": "الحجر", "en": "সূরা হিজর"},
    {"num": "16", "ar": "النحل", "en": "সূরা নাহল"},
    {"num": "17", "ar": "الإسراء", "en": "সূরা বনী ইসরাঈল"},
    {"num": "18", "ar": "الكهف", "en": "সূরা কাহফ"},
    {"num": "19", "ar": "مريم", "en": "সূরা মারইয়াম"},
    {"num": "20", "ar": "طه", "en": "সূরা ত্বা-হা"},
    {"num": "21", "ar": "الأنبياء", "en": "সূরা আম্বিয়া"},
    {"num": "22", "ar": "الحج", "en": "সূরা হজ্জ"},
    {"num": "23", "ar": "المؤمنون", "en": "সূরা মুমিনূন"},
    {"num": "24", "ar": "النور", "en": "সূরা নূর"},
    {"num": "25", "ar": "الفرقان", "en": "সূরা ফুরকান"},
    {"num": "26", "ar": "الشعراء", "en": "সূরা শুআরা"},
    {"num": "27", "ar": "النمل", "en": "সূরা নামল"},
    {"num": "28", "ar": "القصص", "en": "সূরা কাসাস"},
    {"num": "29", "ar": "العنكبوت", "en": "সূরা আনকাবূত"},
    {"num": "30", "ar": "الروم", "en": "সূরা রূম"},
    {"num": "31", "ar": "لقمان", "en": "সূরা লোকমান"},
    {"num": "32", "ar": "السجدة", "en": "সূরা সিজদাহ"},
    {"num": "33", "ar": "الأحزاب", "en": "সূরা আহযাব"},
    {"num": "34", "ar": "سبإ", "en": "সূরা সাবা"},
    {"num": "35", "ar": "فاطر", "en": "সূরা ফাতির"},
    {"num": "36", "ar": "يس", "en": "সূরা ইয়াসীন"},
    {"num": "37", "ar": "الصافات", "en": "সূরা সাফফাত"},
    {"num": "38", "ar": "ص", "en": "সূরা ছোয়াদ"},
    {"num": "39", "ar": "الزمر", "en": "সূরা যুমার"},
    {"num": "40", "ar": "غافر", "en": "সূরা গাফির"},
    {"num": "41", "ar": "فصلت", "en": "সূরা ফুসসিলাত"},
    {"num": "42", "ar": "الشورى", "en": "সূরা শূরা"},
    {"num": "43", "ar": "الزخرف", "en": "সূরা যুখরুফ"},
    {"num": "44", "ar": "الدخان", "en": "সূরা দুখান"},
    {"num": "45", "ar": "الجاثية", "en": "সূরা জাসিয়াহ"},
    {"num": "46", "ar": "الأحقاف", "en": "সূরা আহকাফ"},
    {"num": "47", "ar": "محمد", "en": "সূরা মুহাম্মদ"},
    {"num": "48", "ar": "الفتح", "en": "সূরা ফাতহ"},
    {"num": "49", "ar": "الحجرات", "en": "সূরা হুজুরাত"},
    {"num": "50", "ar": "ق", "en": "সূরা কাফ"},
    {"num": "51", "ar": "الذاريات", "en": "সূরা যারিয়াত"},
    {"num": "52", "ar": "الطور", "en": "সূরা তূর"},
    {"num": "53", "ar": "النجم", "en": "সূরা নাজম"},
    {"num": "54", "ar": "القمر", "en": "সূরা কামার"},
    {"num": "55", "ar": "الرحمن", "en": "সূরা রহমান"},
    {"num": "56", "ar": "الواقعة", "en": "সূরা ওয়াকিয়াহ"},
    {"num": "57", "ar": "الحديد", "en": "সূরা হাদীদ"},
    {"num": "58", "ar": "المجادلة", "en": "সূরা মুজাদালাহ"},
    {"num": "59", "ar": "الحشر", "en": "সূরা হাশর"},
    {"num": "60", "ar": "الممتحنة", "en": "সূরা মুমতাহিনাহ"},
    {"num": "61", "ar": "الصف", "en": "সূরা সাফ"},
    {"num": "62", "ar": "الجمعة", "en": "সূরা জুমুআহ"},
    {"num": "63", "ar": "المنافقون", "en": "সূরা মুনাফিকূন"},
    {"num": "64", "ar": "التغابن", "en": "সূরা তাগাবুন"},
    {"num": "65", "ar": "الطلاق", "en": "সূরা তালাক"},
    {"num": "66", "ar": "التحريم", "en": "সূরা তাহরীম"},
    {"num": "67", "ar": "الملك", "en": "সূরা মুলক"},
    {"num": "68", "ar": "القلم", "en": "সূরা কালাম"},
    {"num": "69", "ar": "الحاقة", "en": "সূরা হাক্কাহ"},
    {"num": "70", "ar": "المعارج", "en": "সূরা মাআরিজ"},
    {"num": "71", "ar": "نوح", "en": "সূরা নূহ"},
    {"num": "72", "ar": "الجن", "en": "সূরা জিন"},
    {"num": "73", "ar": "المزمل", "en": "সূরা মুযযাম্মিল"},
    {"num": "74", "ar": "المدثر", "en": "সূরা মুদ্দাসসির"},
    {"num": "75", "ar": "القيامة", "en": "সূরা কিয়ামাহ"},
    {"num": "76", "ar": "الانسان", "en": "সূরা ইনসান"},
    {"num": "77", "ar": "المرسلات", "en": "সূরা মুরসালাত"},
    {"num": "78", "ar": "النبإ", "en": "সূরা নাবা"},
    {"num": "79", "ar": "النازعات", "en": "সূরা নাযিআত"},
    {"num": "80", "ar": "عبس", "en": "সূরা আবাসা"},
    {"num": "81", "ar": "التكوير", "en": "সূরা তাকভীর"},
    {"num": "82", "ar": "الإنفطار", "en": "সূরা ইনফিতার"},
    {"num": "83", "ar": "المطففين", "en": "সূরা মুতাফফিফীন"},
    {"num": "84", "ar": "الإنشقاق", "en": "সূরা ইনশিকাক"},
    {"num": "85", "ar": "البروج", "en": "সূরা বুরূজ"},
    {"num": "86", "ar": "الطارق", "en": "সূরা তারেক"},
    {"num": "87", "ar": "الأعلى", "en": "সূরা আ'লা"},
    {"num": "88", "ar": "الغاشية", "en": "সূরা গাশিয়াহ"},
    {"num": "89", "ar": "الفجر", "en": "সূরা ফজর"},
    {"num": "90", "ar": "البلد", "en": "সূরা বালাদ"},
    {"num": "91", "ar": "الشمس", "en": "সূরা শামস"},
    {"num": "92", "ar": "الليل", "en": "সূরা লাইল"},
    {"num": "93", "ar": "الضحى", "en": "সূরা যুহা"},
    {"num": "94", "ar": "الشرح", "en": "সূরা ইনশিরাহ"},
    {"num": "95", "ar": "التين", "en": "সূরা তীন"},
    {"num": "96", "ar": "العلق", "en": "সূরা আলাক"},
    {"num": "97", "ar": "القدر", "en": "সূরা কদর"},
    {"num": "98", "ar": "البينة", "en": "সূরা বাইয়্যিনাহ"},
    {"num": "99", "ar": "الزلزلة", "en": "সূরা যিলযাল"},
    {"num": "100", "ar": "العاديات", "en": "সূরা আদিয়াত"},
    {"num": "101", "ar": "القارعة", "en": "সূরা কারিআ"},
    {"num": "102", "ar": "التكاثر", "en": "সূরা তাকাসুর"},
    {"num": "103", "ar": "العصر", "en": "সূরা আসর"},
    {"num": "104", "ar": "الهمزة", "en": "সূরা হুমাযাহ"},
    {"num": "105", "ar": "الفيل", "en": "সূরা ফীল"},
    {"num": "106", "ar": "قريش", "en": "সূরা কুরাইশ"},
    {"num": "107", "ar": "الماعون", "en": "সূরা মাউন"},
    {"num": "108", "ar": "الكوثر", "en": "সূরা কাউসার"},
    {"num": "109", "ar": "الكافرون", "en": "সূরা কাফিরূন"},
    {"num": "110", "ar": "النصر", "en": "সূরা নাসর"},
    {"num": "111", "ar": "المسد", "en": "সূরা মাসাদ"},
    {"num": "112", "ar": "الإخلاص", "en": "সূরা ইখলাস"},
    {"num": "113", "ar": "الفلق", "en": "সূরা ফালাক"},
    {"num": "114", "ar": "الناس", "en": "সূরা নাস"},
  ];

  @override
  void initState() {
    super.initState();
    // Warm the surah corpus in the background. The first search the user
    // runs still waits for the first batch, but by the second keystroke
    // every surah is local and search is essentially free.
    // ignore: discarded_futures
    QuranApi.prefetchAll();
  }

  @override
  void dispose() {
    // Tear down the shared audio player so closing the Quran page does
    // not leave a stream running in the background. The service itself
    // is a singleton, but stopping its playback is the right thing to
    // do when the user navigates away.
    QuranAudioService.instance.stop();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Handle taps on the play/stop icon next to a Surah. Shows a
  /// SnackBar on failure so the user sees a Bangla message rather than
  /// a raw exception. The icon swap itself is driven by the service's
  /// ValueNotifier so every tile updates from a single source.
  Future<void> _onPlayTap(int surahNumber) async {
    try {
      await QuranAudioService.instance.togglePlay(surahNumber);
    } on QuranAudioNeedsInternetException catch (_) {
      // First-time download failed because the device is offline.
      // Tell the user *exactly* that — the audio isn't broken, it
      // just needs a one-time online listen to be cached for offline
      // playback.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Tr.quranAudioFirstTimeNeedsNetwork(context)),
          duration: const Duration(seconds: 5),
        ),
      );
    } on QuranAudioDownloadFailedException catch (_) {
      // First-time download failed for a non-network reason (CDN
      // error, timeout on a flaky link, full disk, etc.). Do NOT
      // blame the internet here — the message stays generic so the
      // user retries instead of restarting their router.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Tr.quranAudioDownloadFailed(context)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Tr.quranAudioFailed(context))));
    }
  }

  Future<void> _showReaderSettings() async {
    final settings = SettingsService.instance;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: AnimatedBuilder(
          animation: settings,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.quranReadingSettings(context),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Text(Tr.quranArabicFont(context)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: settings.quranArabicFont,
                  items: SettingsService.quranArabicFonts
                      .map(
                        (font) =>
                            DropdownMenuItem(value: font, child: Text(font)),
                      )
                      .toList(),
                  onChanged: (font) {
                    if (font != null) settings.setQuranArabicFont(font);
                  },
                ),
                const SizedBox(height: 14),
                _ReaderSizeSlider(
                  title: Tr.quranArabicSize(context),
                  value: settings.quranArabicSize,
                  min: 16,
                  max: 36,
                  onChanged: settings.setQuranArabicSize,
                ),
                _ReaderSizeSlider(
                  title: Tr.quranBanglaSize(context),
                  value: settings.quranBanglaSize,
                  min: 12,
                  max: 24,
                  onChanged: settings.setQuranBanglaSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSurah(int number) async {
    setState(() {
      _loadingSurah = true;
      _selectedSurah = null;
    });
    try {
      final s = await QuranApi.fetchSurah(number);
      if (!mounted) return;
      // If the API returned the offline placeholder (no cache AND no
      // network), surface a friendly in-page notice instead of an
      // empty Surah screen.
      if (s.englishName == 'Offline') {
        setState(() {
          _selectedSurah = s;
          _surahOfflineNotice = true;
        });
      } else {
        setState(() {
          _selectedSurah = s;
          _surahOfflineNotice = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is QuranOfflineException
                ? Tr.quranOfflineShort(context)
                : '${Tr.quranLoadFailed(context)}$e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingSurah = false);
    }
  }

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;

    final surahNumber = _findSurahNumber(q);
    if (surahNumber != null) {
      setState(() {
        _prioritizedSurahNumber = surahNumber;
        _searchResults = [];
        _surahTab = 0;
      });
      return;
    }

    setState(() {
      _searching = true;
      _prioritizedSurahNumber = null;
      _searchResults = [];
      _surahTab = 1;
    });
    try {
      final hits = await QuranApi.search(q);
      if (!mounted) return;
      setState(() => _searchResults = hits);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is QuranOfflineException
                ? Tr.quranSearchOffline(context)
                : '${Tr.quranSearchFailed(context)}$e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  int? _findSurahNumber(String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return null;

    for (final surah in _surahList) {
      final number = surah['num']!;
      final names = <String>[
        surah['en']!,
        surah['ar']!,
      ].map(_normalizeSearchText);
      if (names.any((name) => name.contains(normalizedQuery)) ||
          number == normalizedQuery) {
        return int.parse(number);
      }
    }
    return null;
  }

  String _normalizeSearchText(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'^\s*সূরা\s*'), '')
      .replaceAll(
        RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'),
        '',
      )
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  List<Map<String, String>> get _orderedSurahList {
    final prioritizedNumber = _prioritizedSurahNumber;
    if (prioritizedNumber == null) return _surahList;

    final ordered = List<Map<String, String>>.of(_surahList);
    final index = ordered.indexWhere(
      (surah) => int.parse(surah['num']!) == prioritizedNumber,
    );
    if (index > 0) {
      final match = ordered.removeAt(index);
      ordered.insert(0, match);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to language changes so all UI chrome here rebuilds when
    // the user flips the toggle in Settings.
    SettingsScope.of(context);
    if (_selectedSurah != null) {
      return _buildSurahReader(_selectedSurah!);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F7),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: Tr.libraryQuran(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: Tr.quranSearchHint(context),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF0F4F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _runSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _searching ? null : _runSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E4E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      child: Text(Tr.quranSearchButton(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _tabChip(Tr.quranTabList(context), 0),
                    const SizedBox(width: 8),
                    _tabChip(Tr.quranTabResults(context), 1),
                    const Spacer(),
                    if (_surahTab == 1 && _searchResults.isNotEmpty)
                      Text(
                        '${_searchResults.length}${Tr.quranHitsSuffix(context)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _surahTab == 0 ? _buildSurahList() : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int idx) {
    final selected = _surahTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _surahTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B5E4E) : const Color(0xFFE0E6E4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF1B5E4E),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSurahList() {
    final surahs = _orderedSurahList;
    return _loadingSurah
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: surahs.length,
            itemBuilder: (context, i) {
              final s = surahs[i];
              final num = int.parse(s["num"]!);
              // Each tile rebuilds only when the service fires a
              // state change (start/stop). ValueListenableBuilder
              // keeps the rest of the list static, so scrolling
              // stays smooth even with 114 cards.
              return ValueListenableBuilder<int?>(
                valueListenable: QuranAudioService.instance.currentSurah,
                builder: (context, currentSurah, _) {
                  final isPlaying = currentSurah == num;
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1B5E4E),
                        foregroundColor: Colors.white,
                        child: Text(s["num"]!),
                      ),
                      title: Text(
                        '${s["en"]}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        s["ar"]!,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      // The play button lives on the right side of the
                      // tile. We sit it to the LEFT of the existing
                      // arrow chevron so the chevron still hints at
                      // "tap to read". A green play icon turns into
                      // a red stop icon while this surah is the
                      // currently active one.
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SurahPlayButton(
                            surahNumber: num,
                            isPlaying: isPlaying,
                            onTap: () => _onPlayTap(num),
                          ),
                          // Subtle "downloaded" hint. Listens to the
                          // same notifier as the play button so it
                          // flips from cloud_off → cloud_done the
                          // instant the first listen finishes.
                          ValueListenableBuilder<int?>(
                            valueListenable:
                                QuranAudioService.instance.currentSurah,
                            builder: (context, current, _) {
                              final cached =
                                  QuranAudioService.instance.isCached(num) ||
                                  current == num;
                              if (!cached) {
                                return const SizedBox(width: 24);
                              }
                              return Tooltip(
                                message: Tr.quranOfflineReady(context),
                                child: const Icon(
                                  Icons.cloud_done,
                                  size: 16,
                                  color: Color(0xFF1B5E4E),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      onTap: () => _openSurah(num),
                    ),
                  );
                },
              );
            },
          );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isEmpty
                  ? Tr.quranEmptyPrompt(context)
                  : '"${_searchCtrl.text}"${Tr.quranNoResults(context)}',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final hit = _searchResults[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${Tr.quranSurahPrefix(context)}${hit.surahNumber} • ${hit.surahName}',
                        style: const TextStyle(
                          color: Color(0xFF1B5E4E),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hit.ayah.text.isNotEmpty)
                  Text(
                    hit.ayah.text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  hit.ayah.translation,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurahReader(SurahDetail s) {
    // Subscribe to language changes for the Tr.* calls below.
    SettingsScope.of(context);
    // Offline placeholder path: render a friendly notice instead of an
    // empty Surah so the user understands what happened and what to do
    // next (go online once to populate the cache).
    if (_surahOfflineNotice) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppAppBar(
          title: AppAppBar.kMasjidName,
          subtitle: '${Tr.quranSurahPrefix(context)}${s.number}',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => setState(() {
              _selectedSurah = null;
              _surahOfflineNotice = false;
            }),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  Tr.quranOfflineTitle(context),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Tr.quranOfflineBody(context),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: '${Tr.quranSurahPrefix(context)}${s.name} (${s.number})',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() {
            _selectedSurah = null;
            _surahOfflineNotice = false;
          }),
        ),
        actions: [
          // Play/stop icon in the reader header — lets users start the
          // recitation while reading the ayahs without scrolling back
          // to the list. The icon mirrors the list-tile icon so the
          // affordance is consistent.
          ValueListenableBuilder<int?>(
            valueListenable: QuranAudioService.instance.currentSurah,
            builder: (context, currentSurah, _) {
              final isPlaying = currentSurah == s.number;
              return ValueListenableBuilder<bool>(
                valueListenable: QuranAudioService.instance.isLoading,
                builder: (context, loading, _) {
                  final showSpinner = loading && isPlaying;
                  return IconButton(
                    tooltip: isPlaying
                        ? Tr.quranStopTooltip(context)
                        : QuranAudioService.instance.isCached(s.number)
                        ? '${Tr.quranPlayTooltip(context)} • '
                              '${Tr.quranAudioSource(context)} • '
                              '${Tr.quranOfflineReady(context)}'
                        : '${Tr.quranPlayTooltip(context)} • '
                              '${Tr.quranAudioSource(context)} • '
                              '${Tr.quranAudioFirstTimeNeedsNetwork(context)}',
                    icon: showSpinner
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isPlaying
                                ? Icons.stop_circle
                                : Icons.play_circle_fill,
                            color: Colors.white,
                            size: 28,
                          ),
                    onPressed: () => _onPlayTap(s.number),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: Tr.quranReadingSettings(context),
            onPressed: _showReaderSettings,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: s.ayahs.length,
        itemBuilder: (context, i) {
          // The Al-Quran Cloud API returns each ayah's *global* number
          // across the whole mushaf (Surah 2 starts at 8 because Surah 1
          // has 7 ayahs). We render the *ayah-within-this-surah* index
          // (1, 2, 3 …) so every Surah reader starts at "আয়াত 1",
          // matching the user's expectation and the on-screen bismillah.
          final ayahIndexInSurah = i + 1;
          final a = s.ayahs[i];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF1B5E4E),
                      foregroundColor: Colors.white,
                      child: Text(
                        '$ayahIndexInSurah',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${Tr.quranAyah(context)}$ayahIndexInSurah',
                      style: const TextStyle(
                        color: Color(0xFF1B5E4E),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    a.text,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: SettingsService.instance.quranArabicSize,
                      fontFamily: SettingsService.instance.quranArabicFont,
                      color: Color(0xFF2C3E50),
                      height: 1.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: const Color(0xFFE0E6E4)),
                const SizedBox(height: 10),
                Text(
                  a.translation.isEmpty ? '—' : a.translation,
                  style: TextStyle(
                    fontSize: SettingsService.instance.quranBanglaSize,
                    color: Color(0xFF34495E),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Round play/stop icon used on each Surah tile. Pulls the
/// `isLoading` notifier separately so the icon can spin while the
/// stream is buffering, then snap to a stop icon once playback starts.
class _ReaderSizeSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _ReaderSizeSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(title)),
          Text(value.round().toString()),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: (max - min).round(),
        onChanged: onChanged,
      ),
    ],
  );
}

class _SurahPlayButton extends StatelessWidget {
  final int surahNumber;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SurahPlayButton({
    required this.surahNumber,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: QuranAudioService.instance.isLoading,
      builder: (context, loading, _) {
        // Three states:
        //   1. streaming/buffering (loading && isPlaying)  → spinner
        //      with download progress on first listen, generic
        //      spinner for cached replays.
        //   2. playing (isPlaying)                          → red stop icon
        //   3. idle                                          → green play icon
        final showDownloadRing = loading && isPlaying;
        return ValueListenableBuilder<double>(
          valueListenable: QuranAudioService.instance.downloadProgress,
          builder: (context, progress, _) {
            return IconButton(
              tooltip: isPlaying
                  ? Tr.quranStopTooltip(context)
                  : Tr.quranPlayTooltip(context),
              icon: showDownloadRing
                  ? _DownloadRing(
                      progress: progress,
                      size: 32,
                      color: const Color(0xFF1B5E4E),
                    )
                  : Icon(
                      isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                      size: 32,
                      color: isPlaying
                          ? const Color(0xFFC62828)
                          : const Color(0xFF1B5E4E),
                    ),
              onPressed: onTap,
            );
          },
        );
      },
    );
  }
}

/// Small circular ring that fills clockwise as a Surah MP3 is
/// downloaded the first time. Falls back to an indeterminate spinner
/// when the server doesn't report `content-length` (progress = 0).
class _DownloadRing extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;

  const _DownloadRing({
    required this.progress,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: progress > 0.0
          ? CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: color.withValues(alpha: 0.15),
            )
          : const CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Color(0xFF1B5E4E),
            ),
    );
  }
}
