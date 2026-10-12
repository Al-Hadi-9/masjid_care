import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';

/// User-facing settings screen.
///
/// Reached from the drawer (and currently from the AppBar overflow).
/// Contains three independent option groups:
///
///   1. School of thought (Madhhab) — radio between Hanafi and the
///      Shafi/Maliki/Hanbali group. Changes how Asr is computed.
///   2. Location — opens a small dialog with City / Country text fields.
///      Changes which row of the aladhan.com `calendarByCity` endpoint
///      we hit.
///   3. Language — Bangla / English toggle. Drives the bottom nav labels
///      and the home-page item-card labels via [Tr].
///
/// Each option persists to SharedPreferences immediately on change so the
/// app does not have to be restarted to keep its choices.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  /// Opens the division/district location picker used by the Settings
  /// page. Exposed as a static helper so other entry points (e.g. the
  /// side drawer) can launch the same dialog without re-implementing
  /// the dropdown wiring.
  ///
  /// Returns the picked `(city, country)` pair, or `null` if the user
  /// dismissed the dialog without saving.
  static Future<({String city, String country})?> showLocationPicker(
    BuildContext context,
  ) {
    final settings = SettingsService.instance;
    return _showLocationDialog(context, settings);
  }
}

class _SettingsPageState extends State<SettingsPage> {
  // We listen to the SettingsService so the page rebuilds when *any*
  // option changes — including from elsewhere in the app. Even though
  // this screen owns all three options today, that pattern keeps the
  // page consistent if we later add shortcuts (e.g. "reset to defaults").
  late final SettingsService _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService.instance;
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F7),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: Tr.settingsTitle(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── School of thought ────────────────────────────────────────
          _SectionCard(
            title: Tr.settingsSchool(context),
            subtitle: Tr.settingsSchoolDesc(context),
            icon: Icons.balance,
            child: Column(
              children: [
                _RadioTile<Madhhab>(
                  value: Madhhab.hanafi,
                  groupValue: _settings.madhhab,
                  onChanged: (v) => _settings.setMadhhab(v),
                  label: _settings.isBangla
                      ? Madhhab.hanafi.bangla
                      : Madhhab.hanafi.english,
                  description: _settings.isBangla ? '' : '',
                ),
                const Divider(height: 1),
                _RadioTile<Madhhab>(
                  value: Madhhab.shafiMalikiHanbali,
                  groupValue: _settings.madhhab,
                  onChanged: (v) => _settings.setMadhhab(v),
                  label: _settings.isBangla
                      ? Madhhab.shafiMalikiHanbali.bangla
                      : Madhhab.shafiMalikiHanbali.english,
                  description: _settings.isBangla ? '' : '',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Location ─────────────────────────────────────────────────
          _SectionCard(
            title: Tr.settingsLocation(context),
            subtitle: Tr.settingsLocationDesc(context),
            icon: Icons.location_on,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    Tr.settingsCurrentLocation(context),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '${_settings.city}, ${_settings.country}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.edit_location_alt,
                    color: Color(0xFF1B5E4E),
                  ),
                  title: Text(Tr.settingsChangeLocation(context)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.black38,
                  ),
                  onTap: () => _showLocationDialog(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Language ─────────────────────────────────────────────────
          _SectionCard(
            title: Tr.settingsLanguage(context),
            subtitle: Tr.settingsLanguageDesc(context),
            icon: Icons.translate,
            child: Column(
              children: [
                _RadioTile<AppLanguage>(
                  value: AppLanguage.bangla,
                  groupValue: _settings.language,
                  onChanged: (v) => _settings.setLanguage(v),
                  label: 'বাংলা',
                  description: 'Bangla',
                ),
                const Divider(height: 1),
                _RadioTile<AppLanguage>(
                  value: AppLanguage.english,
                  groupValue: _settings.language,
                  onChanged: (v) => _settings.setLanguage(v),
                  label: 'English',
                  description: 'ইংরেজি',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showLocationDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await SettingsPage.showLocationPicker(context);
    if (result == null) return;
    if (result.city.isEmpty || result.country.isEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _settings.isBangla
                ? 'বিভাগ ও জেলা উভয়ই বাছাই করতে হবে'
                : 'Please pick both a division and a district',
          ),
        ),
      );
      return;
    }
    await _settings.setLocation(city: result.city, country: result.country);
    // `setLocation` already invalidates PrayerTimeService.invalidate(),
    // which drops the in-memory cache. The next UI visit will trigger
    // a fresh network fetch using the new city/country.
  }
}

/// Static implementation of the location picker dialog. Lives at the
/// library level (not on the State) so it can be reused from places
/// that don't already own a [SettingsPage] instance — e.g. the side
/// drawer — without duplicating the dropdown wiring.
Future<({String city, String country})?> _showLocationDialog(
  BuildContext context,
  SettingsService settings,
) async {
  // Pre-select the current city if it's one of the districts we know
  // about; otherwise default to the first division's first district.
  // The dialog itself is stateful so the district dropdown can
  // refresh when the user picks a new division.
  Division? selectedDivision;
  String? selectedDistrict;
  for (final d in kBangladeshDivisions) {
    if (d.districts.contains(settings.city)) {
      selectedDivision = d;
      selectedDistrict = settings.city;
      break;
    }
  }
  selectedDivision ??= kBangladeshDivisions.first;
  selectedDistrict ??= selectedDivision.districts.first;

  return showDialog<({String city, String country})>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          // Resolve the working division/district each rebuild so
          // the dropdowns reflect the user's latest tap. This guard
          // covers the case where the persisted city isn't in the
          // static list (e.g. user typed "London" before this
          // picker existed).
          Division div = selectedDivision!;
          String dist = selectedDistrict!;
          for (final d in kBangladeshDivisions) {
            if (d.districts.contains(dist)) {
              div = d;
              break;
            }
          }
          if (!div.districts.contains(dist)) {
            dist = div.districts.first;
          }
          return AlertDialog(
            title: Text(Tr.settingsChangeLocation(ctx)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Division>(
                  initialValue: div,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: Tr.settingsDivisionHint(ctx),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.map),
                  ),
                  items: [
                    for (final d in kBangladeshDivisions)
                      DropdownMenuItem(
                        value: d,
                        child: Text(settings.isBangla ? d.nameBn : d.nameEn),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() {
                      selectedDivision = v;
                      // Reset district to the first one of the new
                      // division so the second dropdown stays in a
                      // consistent state.
                      selectedDistrict = v.districts.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: dist,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: Tr.settingsDistrictHint(ctx),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_city),
                  ),
                  items: [
                    for (final name in div.districts)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() => selectedDistrict = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(Tr.settingsCancel(ctx)),
              ),
              ElevatedButton(
                onPressed: () {
                  final pickedDiv = selectedDivision;
                  final pickedDist = selectedDistrict;
                  if (pickedDiv == null || pickedDist == null) return;
                  Navigator.pop(ctx, (city: pickedDist, country: 'Bangladesh'));
                },
                child: Text(Tr.settingsSave(ctx)),
              ),
            ],
          );
        },
      );
    },
  );
}

// ── small helper widgets (kept local — they're not reused elsewhere) ────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E4E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF1B5E4E), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Material(color: Colors.transparent, child: child),
        ],
      ),
    );
  }
}

class _RadioTile<T> extends StatelessWidget {
  const _RadioTile({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.label,
    this.description,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  final String label;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final desc = description;
    return ListTile(
      onTap: () => onChanged(value),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? const Color(0xFF1B5E4E) : Colors.black38,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: const Color(0xFF2C3E50),
        ),
      ),
      subtitle: desc == null
          ? null
          : Text(
              desc,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
    );
  }
}

// ── static Bangladesh location data ──────────────────────────────────────

/// One administrative division of Bangladesh, plus its list of districts.
///
/// Used by the location-change dialog in `_showLocationDialog`. We keep
/// the names in both Bangla and English so the division dropdown can
/// switch language on the fly without rebuilding the district list.
class Division {
  const Division({
    required this.nameEn,
    required this.nameBn,
    required this.districts,
  });

  final String nameEn;
  final String nameBn;
  final List<String> districts;
}

/// The eight divisions of Bangladesh with their districts. District names
/// are sent verbatim to aladhan.com's `calendarByCity` endpoint as the
/// "city" parameter — the API understands them directly.
const List<Division> kBangladeshDivisions = [
  Division(
    nameEn: 'Dhaka',
    nameBn: 'ঢাকা',
    districts: [
      'Dhaka',
      'Faridpur',
      'Gazipur',
      'Gopalganj',
      'Kishoreganj',
      'Madaripur',
      'Manikganj',
      'Munshiganj',
      'Narayanganj',
      'Narsingdi',
      'Rajbari',
      'Shariatpur',
      'Tangail',
    ],
  ),
  Division(
    nameEn: 'Chattogram',
    nameBn: 'চট্টগ্রাম',
    districts: [
      'Chattogram',
      'Bandarban',
      'Brahmanbaria',
      'Chandpur',
      'Comilla',
      'Cox\'s Bazar',
      'Feni',
      'Khagrachari',
      'Lakshmipur',
      'Noakhali',
      'Rangamati',
    ],
  ),
  Division(
    nameEn: 'Rajshahi',
    nameBn: 'রাজশাহী',
    districts: [
      'Rajshahi',
      'Bogura',
      'Chapainawabganj',
      'Joypurhat',
      'Naogaon',
      'Natore',
      'Nawabganj',
      'Pabna',
      'Sirajganj',
    ],
  ),
  Division(
    nameEn: 'Khulna',
    nameBn: 'খুলনা',
    districts: [
      'Khulna',
      'Bagerhat',
      'Chuadanga',
      'Jashore',
      'Jhenaidah',
      'Kushtia',
      'Magura',
      'Meherpur',
      'Narail',
      'Satkhira',
    ],
  ),
  Division(
    nameEn: 'Barishal',
    nameBn: 'বরিশাল',
    districts: [
      'Barishal',
      'Barguna',
      'Bhola',
      'Jhalokati',
      'Patuakhali',
      'Pirojpur',
    ],
  ),
  Division(
    nameEn: 'Sylhet',
    nameBn: 'সিলেট',
    districts: ['Sylhet', 'Habiganj', 'Moulvibazar', 'Sunamganj'],
  ),
  Division(
    nameEn: 'Rangpur',
    nameBn: 'রংপুর',
    districts: [
      'Rangpur',
      'Dinajpur',
      'Gaibandha',
      'Kurigram',
      'Lalmonirhat',
      'Nilphamari',
      'Panchagarh',
      'Thakurgaon',
    ],
  ),
  Division(
    nameEn: 'Mymensingh',
    nameBn: 'ময়মনসিংহ',
    districts: ['Mymensingh', 'Jamalpur', 'Netrokona', 'Sherpur'],
  ),
];
