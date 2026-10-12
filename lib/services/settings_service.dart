import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_time_service.dart';

/// Possible calculation methods accepted by aladhan.com's
/// `calendarByCity` endpoint. We only expose two user-facing options:
///   - [madhhabHanafi]    → method 2 (University of Islamic Sciences, Karachi)
///   - [madhhabShafi]     → method 1 (University of Islamic Sciences, Umm Al-Qura)
/// The "Shafi / Maliki / Hanbali" group is collapsed into a single option
/// in the UI because for *prayer times* the differences between those
/// three schools are negligible — only Hanafi's earlier Asr stands out.
enum Madhhab { hanafi, shafiMalikiHanbali }

extension MadhhabX on Madhhab {
  /// Aladhan method id used by the prayer-times API.
  int get apiMethod {
    switch (this) {
      case Madhhab.hanafi:
        // Hanafi — Karachi method. Asr is computed using Hanafi's
        // shadow-length factor (1.5x shadow of an object instead of 1x).
        return 2;
      case Madhhab.shafiMalikiHanbali:
        // Shafi/Maliki/Hanbali — Umm Al-Qura, Makkah. Asr uses the
        // standard 1x shadow factor.
        return 1;
    }
  }

  String get english {
    switch (this) {
      case Madhhab.hanafi:
        return 'Hanafi';
      case Madhhab.shafiMalikiHanbali:
        return 'Shafi / Maliki / Hanbali';
    }
  }

  String get bangla {
    switch (this) {
      case Madhhab.hanafi:
        return 'হানাফী';
      case Madhhab.shafiMalikiHanbali:
        return 'শাফিঈ / মালেকী / হাম্বলী';
    }
  }
}

/// Available UI languages. Right now only Bangla and English are wired in —
/// the user request specifically calls for these two. Adding more later is
/// purely additive.
enum AppLanguage { bangla, english }

extension AppLanguageX on AppLanguage {
  String get code => this == AppLanguage.bangla ? 'bn' : 'en';
}

/// Global, app-wide settings holder. One instance is created in `main.dart`
/// and exposed through `SettingsScope` so any widget can call
/// `SettingsService.instance` or read it via the inherited widget below.
///
/// Holds three pieces of state:
///   - [language]: which set of UI strings to show (Bangla / English).
///   - [madhhab]:  which school of thought to use for Asr time.
///   - [location]: free-form "City, Country" string sent to aladhan.
///
/// All are persisted in SharedPreferences so the user's choices
/// survive an app restart.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _kLangKey = 'settings_language';
  static const String _kMadhhabKey = 'settings_madhhab';
  static const String _kCityKey = 'settings_city';
  static const String _kCountryKey = 'settings_country';
  static const String _kQuranArabicFontKey = 'quran_arabic_font';
  static const String _kQuranArabicSizeKey = 'quran_arabic_size';
  static const String _kQuranBanglaSizeKey = 'quran_bangla_size';

  AppLanguage _language = AppLanguage.bangla;
  Madhhab _madhhab = Madhhab.hanafi;
  String _city = 'Debidwar';
  String _country = 'Bangladesh';
  String _quranArabicFont = 'Amiri';
  double _quranArabicSize = 21;
  double _quranBanglaSize = 14;

  AppLanguage get language => _language;
  Madhhab get madhhab => _madhhab;
  String get city => _city;
  String get country => _country;
  String get quranArabicFont => _quranArabicFont;
  double get quranArabicSize => _quranArabicSize;
  double get quranBanglaSize => _quranBanglaSize;
  static const List<String> quranArabicFonts = [
    'Amiri',
    'Noto Naskh Arabic',
    'Scheherazade New',
    'Noto Sans Arabic',
  ];

  /// Human-readable label for the currently-selected UI language.
  /// Used by the settings page toggle.
  String get currentLanguageLabel =>
      _language == AppLanguage.bangla ? 'বাংলা' : 'English';

  /// Convenience flag: true when the UI should render in Bangla.
  bool get isBangla => _language == AppLanguage.bangla;

  /// Load persisted values. Safe to call before `runApp` — falls back to
  /// the defaults above if anything is missing or corrupt.
  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString(_kLangKey);
      if (lang == 'en') {
        _language = AppLanguage.english;
      } else {
        _language = AppLanguage.bangla;
      }
      final madhhab = prefs.getString(_kMadhhabKey);
      if (madhhab == 'shafi') {
        _madhhab = Madhhab.shafiMalikiHanbali;
      } else {
        _madhhab = Madhhab.hanafi;
      }
      _city = prefs.getString(_kCityKey) ?? _city;
      _country = prefs.getString(_kCountryKey) ?? _country;
      _quranArabicFont =
          prefs.getString(_kQuranArabicFontKey) ?? _quranArabicFont;
      _quranArabicSize =
          prefs.getDouble(_kQuranArabicSizeKey) ?? _quranArabicSize;
      _quranBanglaSize =
          prefs.getDouble(_kQuranBanglaSizeKey) ?? _quranBanglaSize;
    } catch (_) {
      // Swallow — defaults are fine.
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLangKey, lang.code);
    } catch (_) {}
  }

  Future<void> setMadhhab(Madhhab m) async {
    if (_madhhab == m) return;
    _madhhab = m;
    // Drop the cached prayer times so the next fetch uses the new
    // madhhab's Asr calculation instead of returning stale data.
    PrayerTimeService.invalidate();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kMadhhabKey,
        m == Madhhab.hanafi ? 'hanafi' : 'shafi',
      );
    } catch (_) {}
  }

  Future<void> setLocation({
    required String city,
    required String country,
  }) async {
    _city = city.trim();
    _country = country.trim();
    // Same idea as setMadhhab: the cached timings are for the previous
    // city, so we must invalidate or the API call would be wasted.
    PrayerTimeService.invalidate();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCityKey, _city);
      await prefs.setString(_kCountryKey, _country);
    } catch (_) {}
  }

  Future<void> setQuranArabicFont(String font) async {
    if (!quranArabicFonts.contains(font) || _quranArabicFont == font) return;
    _quranArabicFont = font;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kQuranArabicFontKey, font);
    } catch (_) {}
  }

  Future<void> setQuranArabicSize(double size) async {
    _quranArabicSize = size.clamp(16, 36);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kQuranArabicSizeKey, _quranArabicSize);
    } catch (_) {}
  }

  Future<void> setQuranBanglaSize(double size) async {
    _quranBanglaSize = size.clamp(12, 24);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kQuranBanglaSizeKey, _quranBanglaSize);
    } catch (_) {}
  }
}

/// Inherited widget that simply provides the singleton. Wraps the app so
/// descendants can rebuild when the user flips a setting without us
/// having to thread the service through every constructor.
class SettingsScope extends InheritedNotifier<SettingsService> {
  const SettingsScope({
    super.key,
    required SettingsService service,
    required super.child,
  }) : super(notifier: service);

  static SettingsService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing from widget tree');
    return scope!.notifier!;
  }
}

/// One-stop helper for "give me the Bangla or English version of this
/// label". Pages that have a small handful of static strings can use this
/// without setting up a full i18n framework. If the string set grows much
/// larger we should switch to flutter_localizations + ARB files.
class Tr {
  Tr._();
  static SettingsService _s(BuildContext c) => SettingsScope.of(c);

  // Bottom navigation
  static String navHome(BuildContext c) => _s(c).isBangla ? 'হোম' : 'Home';
  static String navFinance(BuildContext c) =>
      _s(c).isBangla ? 'আয়-ব্যয়' : 'Finance';
  static String navLibrary(BuildContext c) =>
      _s(c).isBangla ? 'লাইব্রেরি' : 'Library';
  static String navProfile(BuildContext c) =>
      _s(c).isBangla ? 'প্রোফাইল' : 'Profile';

  // Home page item cards
  static String homePrayerTime(BuildContext c) =>
      _s(c).isBangla ? 'নামাজের সময়' : 'Prayer Times';
  static String homeForbiddenTime(BuildContext c) =>
      _s(c).isBangla ? 'নামাজের নিষিদ্ধ সময়' : 'Forbidden Times';
  static String homeDonation(BuildContext c) =>
      _s(c).isBangla ? 'দান' : 'Donation';
  static String homeIslamicEvent(BuildContext c) =>
      _s(c).isBangla ? 'ইসলামিক ইভেন্ট' : 'Islamic Events';

  // Drawer / settings
  static String drawerHeader(BuildContext c) =>
      _s(c).isBangla ? 'মেনু' : 'Menu';
  static String drawerSettings(BuildContext c) =>
      _s(c).isBangla ? 'সেটিংস' : 'Settings';
  static String drawerChangeMasjidName(BuildContext c) =>
      _s(c).isBangla ? 'মসজিদের নাম পরিবর্তন' : 'Change masjid name';
  static String drawerLogout(BuildContext c) =>
      _s(c).isBangla ? 'লগআউট' : 'Logout';

  // Settings screen labels
  static String settingsTitle(BuildContext c) =>
      _s(c).isBangla ? 'সেটিংস' : 'Settings';
  static String settingsMasjidName(BuildContext c) =>
      _s(c).isBangla ? 'মসজিদের নাম' : 'Masjid Name';
  static String settingsMasjidNameDesc(BuildContext c) => _s(c).isBangla
      ? 'এই নামটি অ্যাপের একদম উপরে দেখানো হবে'
      : 'Shown in the AppBar at the top of every screen';
  static String settingsMasjidNameHint(BuildContext c) =>
      _s(c).isBangla ? 'মসজিদের নাম লিখুন' : 'Enter masjid name';
  static String settingsMasjidNameEdit(BuildContext c) =>
      _s(c).isBangla ? 'নাম পরিবর্তন করুন' : 'Change name';
  static String settingsMasjidNameSaved(BuildContext c) =>
      _s(c).isBangla ? 'মসজিদের নাম সংরক্ষণ হয়েছে' : 'Masjid name saved';
  static String settingsMasjidNameEmpty(BuildContext c) =>
      _s(c).isBangla ? 'একটি নাম লিখুন' : 'Please enter a name';
  static String settingsSchool(BuildContext c) =>
      _s(c).isBangla ? 'মাযহাব (নামাজের সময়)' : 'School of Thought';
  static String settingsSchoolDesc(BuildContext c) => _s(c).isBangla ? '' : '';
  static String settingsLocation(BuildContext c) =>
      _s(c).isBangla ? 'লোকেশন' : 'Location';
  static String settingsLocationDesc(BuildContext c) => _s(c).isBangla
      ? 'নামাজের সময় গণনার জন্য আপনার শহর বদলান'
      : 'Change your city for prayer times';
  static String settingsLanguage(BuildContext c) =>
      _s(c).isBangla ? 'ভাষা' : 'Language';
  static String settingsLanguageDesc(BuildContext c) =>
      _s(c).isBangla ? '' : '';
  static String settingsSave(BuildContext c) =>
      _s(c).isBangla ? 'সংরক্ষণ করুন' : 'Save';
  static String settingsCancel(BuildContext c) =>
      _s(c).isBangla ? 'বাতিল' : 'Cancel';
  static String settingsDeleteWarningTitle(BuildContext c) =>
      _s(c).isBangla ? 'মসজিদ মুছে ফেলার সতর্কতা' : 'Masjid deletion warning';
  static String settingsDeleteWarning(BuildContext c) => _s(c).isBangla
      ? 'এই কাজটি করলে মসজিদের আয়-ব্যয়ের হিসাব স্থায়ীভাবে মুছে যাবে। এটি পুনরুদ্ধার করা যাবে না। তারপরও আপনি কি চালিয়ে যেতে চান?'
      : 'This will permanently delete the masjid’s income and expense records. This cannot be undone. Do you still want to continue?';
  static String settingsDeleteCancel(BuildContext c) =>
      _s(c).isBangla ? 'বাতিল' : 'Cancel';
  static String settingsDeleteContinue(BuildContext c) =>
      _s(c).isBangla ? 'চালিয়ে যান' : 'Continue';
  static String settingsDeleteConfirmTitle(BuildContext c) =>
      _s(c).isBangla ? 'মুছে ফেলা নিশ্চিত করুন' : 'Confirm deletion';
  static String settingsDeleteConfirm(BuildContext c) => _s(c).isBangla
      ? '\u09ae\u09c1\u099b\u09c7 \u09ab\u09c7\u09b2\u09c1\u09a8'
      : 'Confirm';
  static String settingsDeleteFinalConfirm(BuildContext c) => _s(c).isBangla
      ? '\u0986\u09aa\u09a8\u09bf \u0995\u09bf \u09a8\u09bf\u09b6\u09cd\u099a\u09bf\u09a4\u09ad\u09be\u09ac\u09c7 \u09ae\u09b8\u099c\u09bf\u09a6\u099f\u09bf \u09ae\u09c1\u099b\u09c7 \u09ab\u09c7\u09b2\u09a4\u09c7 \u099a\u09be\u09a8? \u098f\u0987 \u0995\u09be\u099c\u099f\u09bf \u09aa\u09b0\u09c7 \u09ab\u09bf\u09b0\u09bf\u09df\u09c7 \u0986\u09a8\u09be \u09af\u09be\u09ac\u09c7 \u09a8\u09be?'
      : 'Are you sure you want to delete this masjid? This action cannot be undone.';
  static String settingsDeleteSuccess(BuildContext c) => _s(c).isBangla
      ? 'মসজিদের তথ্য মুছে ফেলা হয়েছে'
      : 'Masjid deleted successfully';
  static String settingsDeleteFailed(BuildContext c) =>
      _s(c).isBangla ? 'মসজিদ মুছতে ব্যর্থ: ' : 'Failed to delete masjid: ';
  static String settingsCurrentLocation(BuildContext c) =>
      _s(c).isBangla ? 'বর্তমান লোকেশন' : 'Current location';
  static String settingsChangeLocation(BuildContext c) =>
      _s(c).isBangla ? 'লোকেশন পরিবর্তন করুন' : 'Change location';
  static String settingsDivisionHint(BuildContext c) =>
      _s(c).isBangla ? 'বিভাগ' : 'Division';
  static String settingsDistrictHint(BuildContext c) =>
      _s(c).isBangla ? 'জেলা' : 'District';

  // Change Masjid — leave the active masjid tree and bounce back to
  // the login screen so the user can sign in to (or register) a
  // different masjid. Lives in the Settings page, NOT the bottom
  // nav, by design.
  static String settingsChangeMasjid(BuildContext c) =>
      _s(c).isBangla ? 'মসজিল পরিবর্তন' : 'Change Masjid';
  static String settingsChangeMasjidDesc(BuildContext c) => _s(c).isBangla
      ? 'বর্তমান মসজিল থেকে বের হয়ে অন্য মসজিলে সাইন ইন করুন'
      : 'Leave the current masjid and sign in to a different one';
  static String settingsChangeMasjidConfirmTitle(BuildContext c) =>
      _s(c).isBangla ? 'এই মসজিল ছেড়ে দিতে চান?' : 'Leave this masjid?';
  static String settingsChangeMasjidConfirmBody(BuildContext c) =>
      _s(c).isBangla
      ? 'আপনি এই মসজিল থেকে সাইন আউট হয়ে যাবেন। একই অ্যাকাউন্টে আবার সাইন ইন করতে পারবেন অথবা অন্য অ্যাকাউন্ট ব্যবহার করতে পারবেন।'
      : 'You will be signed out of this masjid. '
            'You can sign in again with the same account or a different one.';
  static String settingsChangeMasjidConfirmYes(BuildContext c) =>
      _s(c).isBangla ? 'হ্যাঁ, বের হন' : 'Sign out';
  static String settingsChangeMasjidConfirmNo(BuildContext c) =>
      _s(c).isBangla ? 'বাতিল' : 'Cancel';
  static String settingsChangeMasjidSignedOut(BuildContext c) => _s(c).isBangla
      ? 'সাইন আউট হয়েছেন। নতুন মসজিলে সাইন ইন করুন।'
      : 'Signed out. Pick a masjid to continue.';

  // Home — current prayer card
  static String homeCurrentWaqt(BuildContext c) =>
      _s(c).isBangla ? 'বর্তমান ওয়াক্ত' : 'Current Prayer';
  static String homeStart(BuildContext c) => _s(c).isBangla ? 'শুরু' : 'Start';
  static String homeEnd(BuildContext c) => _s(c).isBangla ? 'শেষ' : 'End';
  static String homeRemaining(BuildContext c) =>
      _s(c).isBangla ? 'সময় বাকি: ' : 'Remaining: ';
  static String homeElapsed(BuildContext c) =>
      _s(c).isBangla ? 'সময় অতিক্রান্ত: ' : 'Elapsed: ';

  // Library page
  static String libraryTitle(BuildContext c) =>
      _s(c).isBangla ? 'অনলাইন লাইব্রেরি' : 'Online Library';
  static String libraryQuran(BuildContext c) =>
      _s(c).isBangla ? 'আল-কুরআন' : 'Al-Quran';
  static String libraryQuranSub(BuildContext c) => _s(c).isBangla
      ? '১১৪টি সূরা • বাংলা অনুবাদ'
      : '114 Surahs • Bangla Translation';
  static String libraryHadith(BuildContext c) =>
      _s(c).isBangla ? 'হাদীস শরীফ' : 'Hadith Sharif';
  static String libraryHadithSub(BuildContext c) =>
      _s(c).isBangla ? 'সহীহ বুখারী ও মুসলিম' : 'Sahih Bukhari & Muslim';
  static String libraryBooks(BuildContext c) =>
      _s(c).isBangla ? 'ইসলামী বই' : 'Islamic Books';
  static String libraryBooksSub(BuildContext c) =>
      _s(c).isBangla ? '৪টি নির্বাচিত বই' : '4 Selected Books';
  static String libraryDuaZikir(BuildContext c) =>
      _s(c).isBangla ? 'দোয়া ও জিকির' : 'Dua & Zikir';
  static String libraryDuaZikirSub(BuildContext c) =>
      _s(c).isBangla ? 'প্রতিদিনের মাসনুন দোয়া' : 'Daily Masnun Duas';

  // Prayer time page
  static String prayerScheduleTitle(BuildContext c) =>
      _s(c).isBangla ? 'নামাজের সময়সূচী' : 'Prayer Schedule';

  // Forbidden time page
  static String forbiddenTitle(BuildContext c) => _s(c).isBangla
      ? 'নামাজ পড়ার নিষিদ্ধ সময়'
      : 'Forbidden Times for Prayer';
  static String forbiddenSunrise(BuildContext c) =>
      _s(c).isBangla ? 'সূর্যোদয়' : 'Sunrise';
  static String forbiddenMidday(BuildContext c) =>
      _s(c).isBangla ? 'মধ্যাহ্ন' : 'Midday';
  static String forbiddenSunset(BuildContext c) =>
      _s(c).isBangla ? 'সূর্যাস্ত' : 'Sunset';

  // Donation flow
  static String donationProcess(BuildContext c) =>
      _s(c).isBangla ? 'অনুদান প্রক্রিয়া' : 'Donation Process';
  static String donationStep1(BuildContext c) => _s(c).isBangla
      ? 'ধাপ ১: অনুদানের ধরণ ও পরিমাণ নির্বাচন'
      : 'Step 1: Choose Type & Amount';
  static String donationTypeZakat(BuildContext c) =>
      _s(c).isBangla ? 'যাকাত' : 'Zakat';
  static String donationTypeMasjid(BuildContext c) =>
      _s(c).isBangla ? 'মসজিদ' : 'Mosque';
  static String donationTypeMadrasa(BuildContext c) =>
      _s(c).isBangla ? 'মাদ্রাসা' : 'Madrasa';
  static String donationTypeOther(BuildContext c) =>
      _s(c).isBangla ? 'অন্যান্য' : 'Other';
  static String donationAmountHint(BuildContext c) =>
      _s(c).isBangla ? 'পরিমাণ লিখুন' : 'Enter amount';
  static String donationNextPayment(BuildContext c) =>
      _s(c).isBangla ? 'পরবর্তী: পেমেন্ট যাচাই' : 'Next: Payment Verification';
  static String donationAmountRequired(BuildContext c) => _s(c).isBangla
      ? 'অনুদানের পরিমাণ লিখুন'
      : 'Please enter the donation amount';
  static String donationStep2(BuildContext c) => _s(c).isBangla
      ? 'ধাপ ২: ডোনার তথ্য ও পেমেন্ট'
      : 'Step 2: Donor Info & Payment';
  static String donationTypeLabel(BuildContext c) =>
      _s(c).isBangla ? 'অনুদানের ধরন' : 'Donation Type';
  static String donationAmountLabel(BuildContext c) =>
      _s(c).isBangla ? 'পরিমাণ' : 'Amount';
  static String donationMobileHint(BuildContext c) =>
      _s(c).isBangla ? 'মোবাইল নম্বর *' : 'Mobile Number *';
  static String donationInvalidMobile(BuildContext c) => _s(c).isBangla
      ? 'সঠিক মোবাইল নম্বর দিন'
      : 'Please enter a valid mobile number';
  static String donationInvalidAmount(BuildContext c) =>
      _s(c).isBangla ? 'সঠিক পরিমাণ নেই' : 'Invalid amount';
  static String donationSslcommerzHint(BuildContext c) => _s(c).isBangla
      ? 'পেমেন্ট SSLCommerz স্যান্ডবক্সের মাধ্যমে নিরাপদে প্রক্রিয়া করা হবে। '
            'আপনি bKash, Nagad, Rocket বা যেকোনো কার্ড ব্যবহার করতে পারবেন।'
      : 'Payment is securely processed via SSLCommerz sandbox. '
            'You can use bKash, Nagad, Rocket or any card.';
  static String donationPayNow(BuildContext c) =>
      _s(c).isBangla ? 'পেমেন্ট করুন' : 'Pay Now';
  static String donationPayFailed(BuildContext c) =>
      _s(c).isBangla ? 'পেমেন্ট ব্যর্থ হয়েছে' : 'Payment failed';
  static String donationSuccessTitle(BuildContext c) =>
      _s(c).isBangla ? 'অর্থ প্রদান সফল' : 'Payment Successful';
  static String donationTransactionId(BuildContext c) =>
      _s(c).isBangla ? 'ট্রানজ্যাকশন আইডি' : 'Transaction ID';
  static String donationOk(BuildContext c) => _s(c).isBangla ? 'ঠিক আছে' : 'OK';

  // Finance summaries (any_user.dart)
  static String financeTotalIncome(BuildContext c) =>
      _s(c).isBangla ? 'মোট আয়' : 'Total Income';
  static String financeTotalExpense(BuildContext c) =>
      _s(c).isBangla ? 'মোট ব্যয়' : 'Total Expense';
  static String financeCurrentBalance(BuildContext c) =>
      _s(c).isBangla ? 'বর্তমান ব্যালেন্স' : 'Current Balance';

  // Tab bar subtitles in AppShell
  static String tabSubtitleFinance(BuildContext c) =>
      _s(c).isBangla ? 'আয় - ব্যয়ের হিসাব' : 'Finance';
  static String tabSubtitleLibrary(BuildContext c) =>
      _s(c).isBangla ? 'অনলাইন লাইব্রেরি' : 'Library';
  static String tabSubtitleProfile(BuildContext c) =>
      _s(c).isBangla ? 'প্রোফাইল' : 'Profile';

  // Quran page UI chrome (content data kept Bangla-only)
  static String quranSearchHint(BuildContext c) =>
      _s(c).isBangla ? 'কুরআনে সার্চ করুন...' : 'Search the Quran...';
  static String quranSearchButton(BuildContext c) =>
      _s(c).isBangla ? 'খোঁজুন' : 'Search';
  static String quranTabList(BuildContext c) =>
      _s(c).isBangla ? 'সূরা তালিকা' : 'Surah List';
  static String quranTabResults(BuildContext c) =>
      _s(c).isBangla ? 'সার্চ ফলাফল' : 'Search Results';
  static String quranHitsSuffix(BuildContext c) =>
      _s(c).isBangla ? ' টি মিল' : ' hits';
  static String quranEmptyPrompt(BuildContext c) =>
      _s(c).isBangla ? 'সার্চ করতে একটি শব্দ লিখুন' : 'Type a word to search';
  static String quranNoResults(BuildContext c) => _s(c).isBangla
      ? ' এর জন্য কোনো মিল পাওয়া যায়নি'
      : ' — no matches found';
  static String quranSurahPrefix(BuildContext c) =>
      _s(c).isBangla ? 'সূরা ' : 'Surah ';
  static String quranAyah(BuildContext c) =>
      _s(c).isBangla ? 'আয়াত ' : 'Ayah ';
  static String quranOfflineTitle(BuildContext c) =>
      _s(c).isBangla ? 'এই সূরাটি ক্যাশে নেই' : 'This Surah is not cached';
  static String quranOfflineBody(BuildContext c) => _s(c).isBangla
      ? 'ইন্টারনেট নেই এবং এই সূরা আগে কখনো ডাউনলোড হয়নি। '
            'অনলাইনে একবার ওপেন করলে সেভ হয়ে যাবে।'
      : 'No internet and this Surah was never downloaded. '
            'Open it once online and it will be cached.';
  static String quranOfflineShort(BuildContext c) => _s(c).isBangla
      ? 'সূরা লোড করা যাচ্ছে না — ইন্টারনেট নেই এবং এই সূরা ক্যাশেও নেই। '
            'আগে অনলাইনে একবার ওপেন করুন।'
      : 'Unable to load Surah — no internet and not cached. '
            'Open it once online first.';
  static String quranSearchOffline(BuildContext c) => _s(c).isBangla
      ? 'অফলাইনে সার্চ সম্ভব নয় — আগে অনলাইনে কিছু সূরা পড়ুন যাতে ক্যাশে সংরক্ষিত হয়।'
      : 'Offline search unavailable — read some Surahs online first so they cache.';
  static String quranLoadFailed(BuildContext c) =>
      _s(c).isBangla ? 'সূরা লোড ব্যর্থ: ' : 'Surah load failed: ';
  static String quranSearchFailed(BuildContext c) =>
      _s(c).isBangla ? 'সার্চ ব্যর্থ: ' : 'Search failed: ';
  static String quranBackToList(BuildContext c) =>
      _s(c).isBangla ? 'সূরা তালিকায় ফিরুন' : 'Back to Surah list';
  static String quranReadingSettings(BuildContext c) =>
      _s(c).isBangla ? 'পড়ার সেটিংস' : 'Reading settings';
  static String quranArabicFont(BuildContext c) =>
      _s(c).isBangla ? 'আরবি ফন্ট' : 'Arabic font';
  static String quranArabicSize(BuildContext c) =>
      _s(c).isBangla ? 'আরবি লেখার আকার' : 'Arabic text size';
  static String quranBanglaSize(BuildContext c) =>
      _s(c).isBangla ? 'বাংলা লেখার আকার' : 'Bangla text size';
  static String quranAyahOf(BuildContext c) =>
      _s(c).isBangla ? 'আয়াত ' : 'Ayah ';
  static String quranPlayTooltip(BuildContext c) => _s(c).isBangla
      ? 'সূরা শুনুন (শাইখ আস-সুদাইস)'
      : 'Play Surah (Sheikh As-Sudais)';
  static String quranStopTooltip(BuildContext c) =>
      _s(c).isBangla ? 'থামান' : 'Stop';
  static String quranAudioLoading(BuildContext c) =>
      _s(c).isBangla ? 'অডিও লোড হচ্ছে...' : 'Loading audio...';
  static String quranAudioFailed(BuildContext c) => _s(c).isBangla
      ? 'অডিও চালু করা যায়নি — ইন্টারনেট সংযোগ চেক করুন।'
      : 'Could not start audio — please check your internet connection.';
  // Surfaced on the very first listen when no network is available, so
  // the user understands that the surah isn't broken — it just hasn't
  // been downloaded yet because the first play always requires a live
  // connection.
  static String quranAudioFirstTimeNeedsNetwork(BuildContext c) =>
      _s(c).isBangla
      ? 'প্রথমবার অডিও শুনতে ইন্টারনেট সংযোগ লাগবে। একবার ডাউনলোড হলে '
            'পরে ইন্টারনেট ছাড়াই শোনা যাবে।'
      : 'An internet connection is required to listen to an audio for '
            'the first time. Once downloaded, it can be played offline.';
  // Surfaced when the first-time download fails for a reason that is
  // NOT the network being down — e.g. server returned an error, the
  // download timed out on a slow link, or the device ran out of
  // storage. We deliberately do NOT mention the internet here so the
  // user doesn't reboot their router when the real cause is a
  // full-disk or CDN outage.
  static String quranAudioDownloadFailed(BuildContext c) => _s(c).isBangla
      ? 'অডিও ডাউনলোড করা যায়নি। কিছুক্ষণ পর আবার চেষ্টা করুন।'
      : 'Audio download failed. Please try again in a moment.';
  static String quranAudioSource(BuildContext c) => _s(c).isBangla
      ? 'শাইখ আব্দুর রহমান আস-সুদাইস'
      : 'Sheikh Abdurrahman As-Sudais';
  static String quranOfflineReady(BuildContext c) =>
      _s(c).isBangla ? 'ইন্টারনেট ছাড়াই শোনা যাবে' : 'Available offline';

  // Islamic books page UI chrome
  static String booksListLabel(BuildContext c) =>
      _s(c).isBangla ? '৪টি নির্বাচিত ইসলামী বই' : '4 Selected Islamic Books';
  static String booksChapterHeader(BuildContext c) => _s(c).isBangla
      ? 'অধ্যায়সমূহ — পড়তে চাইলে ট্যাপ করুন'
      : 'Chapters — tap to read';
  static String booksChapterLabel(BuildContext c) =>
      _s(c).isBangla ? 'অধ্যায় ' : 'Chapter ';
  static String booksPrev(BuildContext c) =>
      _s(c).isBangla ? 'আগের অধ্যায়' : 'Previous';
  static String booksNext(BuildContext c) =>
      _s(c).isBangla ? 'পরের অধ্যায়' : 'Next';
  static String booksAllPraise(BuildContext c) => _s(c).isBangla
      ? "সকল প্রশংসা মহান আল্লাহ তা'আলার"
      : 'All praise is for Allah, the Almighty';
  static String booksBackToList(BuildContext c) =>
      _s(c).isBangla ? 'বইয়ের তালিকায় ফিরুন' : 'Back to book list';

  // Dua / Zikir page UI chrome
  static String dzTabDua(BuildContext c) => _s(c).isBangla ? 'দোয়া' : 'Dua';
  static String dzTabZikir(BuildContext c) =>
      _s(c).isBangla ? 'জিকির' : 'Zikir';
  static String dzTarget(BuildContext c) =>
      _s(c).isBangla ? 'লক্ষ্য: ' : 'Target: ';
  static String dzTapToCount(BuildContext c) =>
      _s(c).isBangla ? 'ট্যাপ করে গণনা করুন' : 'Tap to count';
  static String dzTargetReached(BuildContext c) =>
      _s(c).isBangla ? 'লক্ষ্য পূরণ হয়েছে' : 'Target reached';
  static String dzReset(BuildContext c) => _s(c).isBangla ? 'রিসেট' : 'Reset';

  // Hadith page UI chrome (religious content stays Bangla-only)
  static String hadithTitle(BuildContext c) =>
      _s(c).isBangla ? 'হাদীস শরীফ' : 'Hadith Sharif';
  static String hadithSearchHint(BuildContext c) =>
      _s(c).isBangla ? 'হাদিসে সার্চ করুন...' : 'Search the Hadith...';
  static String hadithSearchButton(BuildContext c) =>
      _s(c).isBangla ? 'খোঁজুন' : 'Search';
  static String hadithClearSearch(BuildContext c) =>
      _s(c).isBangla ? 'বন্ধ করুন' : 'Close';
  static String hadithFilterAll(BuildContext c) =>
      _s(c).isBangla ? 'সকল' : 'All';
  static String hadithFilterBukhari(BuildContext c) =>
      _s(c).isBangla ? 'বুখারী' : 'Bukhari';
  static String hadithFilterMuslim(BuildContext c) =>
      _s(c).isBangla ? 'মুসলিম' : 'Muslim';
  static String hadithHitsLabel(BuildContext c) =>
      _s(c).isBangla ? 'টি মিল — "' : ' hits — "';
  static String hadithNoResults(BuildContext c) => _s(c).isBangla
      ? '" এর জন্য কোনো মিল পাওয়া যায়নি'
      : '" — no matches found';
  static String hadithNoHadiths(BuildContext c) =>
      _s(c).isBangla ? 'কোনো হাদীস পাওয়া যায়নি' : 'No hadiths found';
  static String hadithLoadFailed(BuildContext c) =>
      _s(c).isBangla ? 'হাদিস লোড ব্যর্থ: ' : 'Hadith load failed: ';
  static String hadithSearchFailed(BuildContext c) =>
      _s(c).isBangla ? 'সার্চ ব্যর্থ: ' : 'Search failed: ';
  static String hadithNoLabel(BuildContext c) =>
      _s(c).isBangla ? 'হাদিস নং ' : 'Hadith No. ';
  static String hadithNarrator(BuildContext c) =>
      _s(c).isBangla ? 'বর্ণনাকারী: ' : 'Narrator: ';
}
