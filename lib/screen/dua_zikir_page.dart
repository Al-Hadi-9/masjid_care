import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

class DuaZikirPage extends StatefulWidget {
  const DuaZikirPage({super.key});

  @override
  State<DuaZikirPage> createState() => _DuaZikirPageState();
}

class _DuaZikirPageState extends State<DuaZikirPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, String>> _duaList = [
    {
      "title": "সূরা ফাতিহা",
      "arabic":
          "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ۝ الرَّحْمَٰنِ الرَّحِيمِ ۝ مَالِكِ يَوْمِ الدِّينِ ۝ إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ۝ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ ۝ صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ",
      "bangla":
          "শুরু করছি আল্লাহর নামে, যিনি পরম দয়ালু, অসীম মেহেরবান। সকল প্রশংসা আল্লাহর জন্য, যিনি সকল সৃষ্টির রব। যিনি দয়ালু, মেহেরবান। যিনি বিচার দিবসের মালিক। আমরা একমাত্র তোমারই ইবাদত করি এবং একমাত্র তোমারই সাহায্য প্রার্থনা করি। আমাদেরকে সরল পথে পরিচালিত কর। তাদের পথে, যাদেরকে তুমি নেয়ামত দান করেছ — যাদের উপর গযব নেমে আসেনি এবং যারা পথভ্রষ্ট হয়নি।",
    },
    {
      "title": "ঘুমানোর আগে দোয়া",
      "arabic": "بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا",
      "bangla":
          "হে আল্লাহ! তোমার নামেই আমি মৃত্যুবরণ করি এবং জীবিত হই (ঘুমাই ও জাগি)।",
    },
    {
      "title": "ঘুম থেকে জাগার দোয়া",
      "arabic":
          "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ",
      "bangla":
          "সকল প্রশংসা আল্লাহর, যিনি আমাদেরকে মৃত্যুর (ঘুমের) পর জীবিত করলেন এবং তাঁরই কাছে প্রত্যাবর্তন।",
    },
    {
      "title": "খাওয়ার আগে দোয়া",
      "arabic": "بِسْمِ اللَّهِ",
      "bangla": "আল্লাহর নামে (শুরু করছি)।",
    },
    {
      "title": "খাওয়ার পরে দোয়া",
      "arabic":
          "الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ",
      "bangla":
          "সকল প্রশংসা আল্লাহর, যিনি আমাদেরকে খাওয়ালেন ও পান করালেন এবং আমাদেরকে মুসলিম বানিয়েছেন।",
    },
    {
      "title": "ঘর থেকে বের হওয়ার দোয়া",
      "arabic":
          "بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
      "bangla":
          "আল্লাহর নামে (বের হচ্ছি)। আল্লাহর উপর ভরসা করলাম। কোনো শক্তি ও ক্ষমতা নেই, কেবল আল্লাহর সাহায্যেই।",
    },
    {
      "title": "ঘরে প্রবেশের দোয়া",
      "arabic":
          "بِسْمِ اللَّهِ وَلَجْنَا وَبِسْمِ اللَّهِ خَرَجْنَا وَعَلَى اللَّهِ رَبِّنَا تَوَكَّلْنَا",
      "bangla":
          "আল্লাহর নামে প্রবেশ করলাম এবং আল্লাহর নামেই বের হলাম। আমাদের রব আল্লাহর উপরই আমরা ভরসা করলাম।",
    },
    {
      "title": "সকাল ও সন্ধ্যার দোয়া",
      "arabic":
          "أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ",
      "bangla":
          "আমরা সকালে উপনীত হলাম এবং সমগ্র রাজত্ব আল্লাহর। সকল প্রশংসা আল্লাহর। আল্লাহ ছাড়া কোনো ইলাহ নেই, তিনি একক, কোনো অংশীদার নেই।",
    },
    {
      "title": "রাস্তায় চলাকালীন দোয়া",
      "arabic":
          "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ",
      "bangla":
          "আল্লাহর নামে, যার নামের সাথে আকাশ ও পৃথিবীতে কোনো কিছুই ক্ষতি করতে পারে না এবং তিনি সর্বশ্রোতা, সর্বজ্ঞ।",
    },
    {
      "title": "অসুস্থতায় দোয়া",
      "arabic": "لَا بَأْسَ طَهُورٌ إِنْ شَاءَ اللَّهُ",
      "bangla":
          "কোনো অসুবিধা নেই, ইনশাআল্লাহ এটি (রোগ) পবিত্রকরণ (গুনাহ থেকে) হবে।",
    },
    {
      "title": "আখিরাতের জন্য দোয়া",
      "arabic":
          "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
      "bangla":
          "হে আমাদের রব! আমাদেরকে দুনিয়াতে কল্যাণ দিন এবং আখিরাতেও কল্যাণ দিন এবং আমাদেরকে জাহান্নামের আযাব থেকে রক্ষা করুন।",
    },
    {
      "title": "আখিরাতে জান্নাতের জন্য দোয়া",
      "arabic":
          "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ وَأَعُوذُ بِكَ مِنَ النَّارِ",
      "bangla":
          "হে আল্লাহ! আমি তোমার কাছে জান্নাত প্রার্থনা করছি এবং জাহান্নাম থেকে তোমার আশ্রয় চাইছি।",
    },
    {
      "title": "মৃত্যু ভালো হোক — দোয়া",
      "arabic":
          "اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى",
      "bangla":
          "হে আল্লাহ! আমি তোমার কাছে হেদায়েত, তাকওয়া, পবিত্রতা ও অভাবমুক্ত জীবন প্রার্থনা করছি। (সুন্নাত — জীবন ও আখিরাতের জন্য কল্যাণকর দোয়া)",
    },
    {
      "title": "দুনিয়ায় ভালো জীবনের জন্য দোয়া",
      "arabic": "رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا",
      "bangla":
          "হে আমাদের রব! আমরা ভুলে গেলে বা ভুল করলে আমাদেরকে পাকড়াও করো না। (পার্থিব জীবনে স্বস্তি ও ক্ষমার জন্য দোয়া)",
    },
    {
      "title": "রিযিক ও দুনিয়ার কল্যাণের দোয়া",
      "arabic":
          "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ وَأَعُوذُ بِكَ مِنَ الْعَجْزِ وَالْكَسَلِ",
      "bangla":
          "হে আল্লাহ! আমি তোমার কাছে দুশ্চিন্তা ও দুঃখ থেকে আশ্রয় চাইছি এবং অক্ষমতা ও অলসতা থেকে আশ্রয় চাইছি। (দুনিয়া ও রিযিকের কল্যাণের জন্য)",
    },
    {
      "title": "বাবা-মায়ের জন্য দোয়া (কুরআনের দোয়া)",
      "arabic": "رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا",
      "bangla":
          "হে আমার রব! তাদের উভয়ের প্রতি রহম করুন, যেমন তারা শৈশবে আমাকে লালন-পালন করেছেন। (সূরা বনী ইসরাঈল, আয়াত ২৪)",
    },
    {
      "title": "মৃত বাবা-মায়ের জন্য দোয়া",
      "arabic":
          "اللَّهُمَّ اغْفِرْ لِوَالِدَيَّ وَارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا",
      "bangla":
          "হে আল্লাহ! আমার পিতা-মাতাকে ক্ষমা করুন এবং তাঁদের প্রতি দয়া করুন, যেমন তাঁরা শৈশবে আমাকে লালন-পালন করেছেন।",
    },
    {
      "title": "বাবা-মায়ের সাথে ভালো ব্যবহারের দোয়া",
      "arabic":
          "رَبِّ أَوْزِعْنِي أَنْ أَشْكُرَ نِعْمَتَكَ الَّتِي أَنْعَمْتَ عَلَيَّ وَعَلَىٰ وَالِدَيَّ",
      "bangla":
          "হে আমার রব! আমাকে তাওফীক দাও যেন তোমার সেই নেয়ামতের শুকরিয়া আদায় করি, যা তুমি আমাকে ও আমার পিতা-মাতাকে দান করেছ।",
    },
  ];

  static const List<Map<String, dynamic>> _zikirList = [
    {
      "title": "সুবহানাল্লাহ",
      "arabic": "سُبْحَانَ اللَّهِ",
      "bangla": "আল্লাহ পবিত্র ও মহান। এটি সাধারণত ৩৩ বার পড়া হয়।",
      "target": 33,
      "color": Color(0xFF1B5E4E),
    },
    {
      "title": "আলহামদুলিল্লাহ",
      "arabic": "الْحَمْدُ لِلَّهِ",
      "bangla": "সকল প্রশংসা আল্লাহর জন্য। এটি সাধারণত ৩৩ বার পড়া হয়।",
      "target": 33,
      "color": Color(0xFF2E7D32),
    },
    {
      "title": "আল্লাহু আকবার",
      "arabic": "اللَّهُ أَكْبَرُ",
      "bangla": "আল্লাহ সবচেয়ে মহান। এটি সাধারণত ৩৪ বার পড়া হয়।",
      "target": 34,
      "color": Color(0xFF00695C),
    },
    {
      "title": "লা ইলাহা ইল্লাল্লাহ",
      "arabic": "لَا إِلَهَ إِلَّا اللَّهُ",
      "bangla": "আল্লাহ ছাড়া কোনো ইলাহ (উপাস্য) নেই। এটি ঈমানের মূল কথা।",
      "target": 100,
      "color": Color(0xFF1B5E4E),
    },
    {
      "title": "আস্তাগফিরুল্লাহ",
      "arabic": "أَسْتَغْفِرُ اللَّهَ",
      "bangla":
          "আমি আল্লাহর কাছে ক্ষমা প্রার্থনা করছি। প্রতিদিন অন্তত ১০০ বার পড়া সুন্নাত।",
      "target": 100,
      "color": Color(0xFF388E3C),
    },
    {
      "title": "দারূদ শরীফ",
      "arabic": "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ",
      "bangla":
          "হে আল্লাহ! মুহাম্মদ (সা.) ও তাঁর পরিবারের প্রতি রহমত বর্ষণ করুন।",
      "target": 100,
      "color": Color(0xFF1B5E4E),
    },
    {
      "title": "লা হাওলা",
      "arabic": "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
      "bangla": "আল্লাহর সাহায্য ছাড়া কোনো শক্তি বা ক্ষমতা নেই।",
      "target": 100,
      "color": Color(0xFF2E7D32),
    },
  ];

  final Map<int, int> _zikirCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _incrementCount(int index) {
    setState(() {
      _zikirCounts[index] = (_zikirCounts[index] ?? 0) + 1;
    });
  }

  void _resetCount(int index) {
    setState(() {
      _zikirCounts[index] = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to language toggle so tab labels and zikir counter UI flip.
    SettingsScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3F0),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: 'দোয়া ও জিকির',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF008000),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.menu_book, size: 20),
              text: Tr.dzTabDua(context),
            ),
            Tab(
              icon: const Icon(Icons.touch_app_outlined, size: 20),
              text: Tr.dzTabZikir(context),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDuaList(), _buildZikirList()],
      ),
    );
  }

  Widget _buildDuaList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _duaList.length,
      itemBuilder: (context, index) {
        final dua = _duaList[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTokens.borderLight),
            boxShadow: AppTokens.softShadow,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF1B5E4E),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              title: Text(
                dua['title']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF2C3E50),
                ),
              ),
              iconColor: const Color(0xFF1B5E4E),
              collapsedIconColor: const Color(0xFF1B5E4E),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBF9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2EBE5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE8EEF1)),
                        ),
                        child: Text(
                          dua['arabic']!,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFF1B5E4E),
                            height: 1.85,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6F3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE0ECE6)),
                        ),
                        child: Text(
                          dua['bangla']!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF34495E),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildZikirList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _zikirList.length,
      itemBuilder: (context, index) {
        final zikir = _zikirList[index];
        final count = _zikirCounts[index] ?? 0;
        final target = zikir['target'] as int;
        final color = zikir['color'] as Color;
        final progress = target == 0
            ? 0.0
            : (count / target).clamp(0.0, 1.0).toDouble();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTokens.borderLight),
            boxShadow: AppTokens.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFC8E6C9),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF1B5E4E),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      zikir['title'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: color.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${Tr.dzTarget(context)}: $target',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EEF1)),
                ),
                child: Text(
                  zikir['arabic'] as String,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 22,
                    color: color,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _zikirDescription(zikir['bangla'] as String),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5A6B78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _incrementCount(index),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.08),
                          color.withValues(alpha: 0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: count >= target
                            ? const Color(0xFF1B5E4E)
                            : color.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: color,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (count >= target) ...[
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Color(0xFF1B5E4E),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              count >= target
                                  ? Tr.dzTargetReached(context)
                                  : Tr.dzTapToCount(context),
                              style: TextStyle(
                                fontSize: 12,
                                color: count >= target
                                    ? const Color(0xFF1B5E4E)
                                    : Colors.grey[700],
                                fontWeight: count >= target
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE8EEF1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _resetCount(index),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(Tr.dzReset(context)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[600],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Colors.red[200]!,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _zikirDescription(String description) {
    final firstSentence = description.split('।').first.trim();
    return firstSentence.isEmpty ? description : '$firstSentence।';
  }
}
