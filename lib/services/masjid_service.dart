import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:math';

import 'auth_service.dart';

/// Holds the *currently active* masjid id and its display name.
///
/// The app is single-tenant by default — there is one active masjid at a
/// time, and every financial document (donations, manual_income,
/// expenses) is stored under that masjid's tree:
///
///   masjids/{masjidId}/donations/...
///   masjids/{masjidId}/manual_income/...
///   masjids/{masjidId}/expenses/...
///   masjids/{masjidId}    ← name + other config lives here
///
/// The id itself is just a slug — `default` is fine for the first
/// deployment. Exposing a masjid-switcher UI is out of scope for this
/// iteration; the id is stored in SharedPreferences so it survives an
/// app restart and is easy to flip once in production.
///
/// The English name is loaded from `masjids/{masjidId}/nameEnglish` and
/// broadcast via
/// [notifyListeners] so every AppBar that listens to this service
/// rebuilds immediately when the admin changes it from Settings.
class MasjidService extends ChangeNotifier {
  MasjidService._();
  static final MasjidService instance = MasjidService._();

  static const String _kIdKey = 'masjid_id';
  static const String _kNameKey = 'masjid_name';
  static const String _kNameBanglaKey = 'masjid_name_bangla';
  static const String _kNameEnglishKey = 'masjid_name_english';
  static const String _kProfilesKey = 'masjid_profiles';

  /// Default slug used the first time the app launches. Safe to keep —
  /// the user only ever needs to change this if they want to run more
  /// than one masjid from the same Firebase project.
  static const String defaultMasjidId = 'default';

  /// Fallback display name used while the Firestore doc is being fetched
  /// or if the user has never visited the Settings page.
  static const String defaultMasjidName = 'আপনার মসজিদ';

  String _id = defaultMasjidId;
  String _name = defaultMasjidName;
  String _nameBangla = defaultMasjidName;
  String _nameEnglish = 'Your Masjid';
  List<Map<String, String>> _profiles = [];

  static const Map<String, String> defaultJamaatTimes = {
    'fajr': '05:20',
    'dhuhr': '13:00',
    'asr': '16:30',
    'maghrib': '18:15',
    'isha': '20:00',
  };
  Map<String, String> _jamaatTimes = Map.from(defaultJamaatTimes);

  String get masjidId => _id;
  String get masjidName => _name;
  String get masjidNameBangla => _nameBangla;
  String get masjidNameEnglish => _nameEnglish;
  bool get hasActiveMasjid => _id != defaultMasjidId;
  List<Map<String, String>> get profiles =>
      List.unmodifiable(_profiles.map(Map<String, String>.from));
  Map<String, String> get jamaatTimes => Map.unmodifiable(_jamaatTimes);

  Future<void> loadJamaatTimes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('masjids')
          .doc(_id)
          .get();
      final raw = snapshot.data()?['jamaatTimes'];
      if (raw is Map) {
        _jamaatTimes = {
          for (final key in defaultJamaatTimes.keys)
            key: (raw[key] ?? defaultJamaatTimes[key]).toString(),
        };
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> saveJamaatTimes(Map<String, String> times) async {
    final normalized = {
      for (final key in defaultJamaatTimes.keys)
        key: times[key] ?? defaultJamaatTimes[key]!,
    };
    await FirebaseFirestore.instance.collection('masjids').doc(_id).set({
      'jamaatTimes': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _jamaatTimes = normalized;
    notifyListeners();
  }

  static const _tokenAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<String> createMasjid({
    required String nameBangla,
    required String nameEnglish,
    required String creatorName,
    required String creatorEmail,
    required String creatorUid,
    String creatorPassword = '',
  }) async {
    final bangla = nameBangla.trim();
    final english = nameEnglish.trim();
    if (bangla.isEmpty || english.isEmpty) {
      throw ArgumentError('Bangla and English masjid names are required.');
    }
    if (creatorName.trim().isEmpty ||
        creatorEmail.trim().isEmpty ||
        creatorUid.trim().isEmpty) {
      throw ArgumentError('Name and email are required.');
    }
    if (creatorPassword.isNotEmpty && creatorPassword.length < 6) {
      throw ArgumentError('Password must be at least 6 characters.');
    }
    final random = Random.secure();
    final firestore = FirebaseFirestore.instance;

    for (var attempt = 0; attempt < 10; attempt++) {
      final token = List.generate(
        6,
        (_) => _tokenAlphabet[random.nextInt(_tokenAlphabet.length)],
      ).join();
      final ref = firestore.collection('masjids').doc(token);
      final created = await firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(ref);
        if (snapshot.exists) return false;
        transaction.set(ref, {
          'token': token,
          'nameBangla': bangla,
          'nameEnglish': english,
          'name': english,
          'ownerUid': creatorUid,
          'ownerName': creatorName.trim(),
          'ownerEmail': creatorEmail.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (created) {
        final adminData = <String, dynamic>{
          'name': creatorName.trim(),
          'email': creatorEmail.trim(),
          'authUid': creatorUid,
          'status': 'approved',
          'masjidToken': token,
          'isOwner': true,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (creatorPassword.isNotEmpty) {
          adminData['passwordHash'] = AuthService.hashPassword(creatorPassword);
        } else {
          adminData['authProvider'] = 'google';
        }
        await firestore.collection('admins').add(adminData);
        await setActiveMasjid(token, nameBangla: bangla, nameEnglish: english);
        return token;
      }
    }
    throw StateError('Could not generate a unique masjid token.');
  }

  Future<String> joinMasjid(String rawToken) async {
    final token = rawToken.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(token)) {
      throw ArgumentError('Token must contain exactly 6 letters or numbers.');
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('masjids')
        .doc(token)
        .get();
    if (!snapshot.exists) throw StateError('No masjid found for this token.');
    final data = snapshot.data()!;
    final english = (data['nameEnglish'] as String?)?.trim().isNotEmpty == true
        ? (data['nameEnglish'] as String).trim()
        : ((data['name'] as String?)?.trim() ?? 'Masjid');
    final bangla = (data['nameBangla'] as String?)?.trim().isNotEmpty == true
        ? (data['nameBangla'] as String).trim()
        : english;
    await setActiveMasjid(token, nameBangla: bangla, nameEnglish: english);
    return english;
  }

  Future<void> setActiveMasjid(
    String id, {
    required String nameBangla,
    required String nameEnglish,
  }) async {
    _id = id.trim().toUpperCase();
    _nameBangla = nameBangla.trim();
    _nameEnglish = nameEnglish.trim();
    _name = _nameEnglish;
    final prefs = await SharedPreferences.getInstance();
    final existingIndex = _profiles.indexWhere(
      (profile) => profile['token'] == _id,
    );
    final profile = <String, String>{
      'token': _id,
      'nameBangla': _nameBangla,
      'nameEnglish': _nameEnglish,
    };
    if (existingIndex == -1) {
      _profiles.add(profile);
    } else {
      _profiles[existingIndex] = profile;
    }
    await prefs.setString(_kIdKey, _id);
    await prefs.setString(_kNameKey, _name);
    await prefs.setString(_kNameBanglaKey, _nameBangla);
    await prefs.setString(_kNameEnglishKey, _nameEnglish);
    await prefs.setString(_kProfilesKey, jsonEncode(_profiles));
    notifyListeners();
  }

  Future<void> logoutCurrentMasjid() async {
    final prefs = await SharedPreferences.getInstance();
    _profiles.removeWhere((profile) => profile['token'] == _id);

    if (_profiles.isEmpty) {
      _id = defaultMasjidId;
      _name = defaultMasjidName;
      _nameBangla = defaultMasjidName;
      _nameEnglish = 'Your Masjid';
      await prefs.remove(_kIdKey);
      await prefs.remove(_kNameKey);
      await prefs.remove(_kNameBanglaKey);
      await prefs.remove(_kNameEnglishKey);
    } else {
      final next = _profiles.first;
      _id = next['token']!;
      _nameBangla = next['nameBangla'] ?? next['nameEnglish']!;
      _nameEnglish = next['nameEnglish']!;
      _name = _nameEnglish;
      await prefs.setString(_kIdKey, _id);
      await prefs.setString(_kNameKey, _name);
      await prefs.setString(_kNameBanglaKey, _nameBangla);
      await prefs.setString(_kNameEnglishKey, _nameEnglish);
    }
    await prefs.setString(_kProfilesKey, jsonEncode(_profiles));
    notifyListeners();
  }

  Future<void> deleteCurrentMasjid({String creatorPassword = ''}) async {
    if (!hasActiveMasjid) {
      throw StateError('No active masjid is selected.');
    }

    final session = await AuthService().currentSession();
    if (session == null || session['masjidToken'] != _id ||
        session['role'] == 'supervisory_admin') {
      throw StateError(
        'Only the masjid account creator can delete this masjid.',
      );
    }
    final firestore = FirebaseFirestore.instance;
    final masjidRef = firestore.collection('masjids').doc(_id);
    final masjidSnapshot = await masjidRef.get();
    final masjidData = masjidSnapshot.data();
    if (!masjidSnapshot.exists || masjidData == null) {
      throw StateError('This masjid no longer exists.');
    }
    final ownerUid = (masjidData['ownerUid'] ?? '').toString();
    final adminQuery = await firestore
        .collection('admins')
        .where('masjidToken', isEqualTo: _id)
        .where('isOwner', isEqualTo: true)
        .limit(1)
        .get();
    if (ownerUid.isEmpty || adminQuery.docs.isEmpty ||
        adminQuery.docs.first.data()['authUid'] != ownerUid ||
        session['authUid'] != ownerUid) {
      throw StateError(
        'Only the masjid account creator can delete this masjid.',
      );
    }

    final email = (session['email'] ?? '').trim();
    var user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != ownerUid) {
      if (email.isEmpty) {
        throw StateError('Creator authentication is required.');
      }
      if (creatorPassword.isEmpty) {
        throw StateError('Creator authentication is required.');
      }
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: creatorPassword,
      );
      user = credential.user;
    }
    if (user == null || user.uid != ownerUid) {
      throw StateError(
        'Only the masjid account creator can delete this masjid.',
      );
    }

    for (final collectionName in ['donations', 'manual_income', 'expenses']) {
      final collection = masjidRef.collection(collectionName);
      while (true) {
        final page = await collection.limit(400).get();
        if (page.docs.isEmpty) break;
        final batch = firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    while (true) {
      final page = await firestore
          .collection('admins')
          .where('masjidToken', isEqualTo: _id)
          .limit(400)
          .get();
      if (page.docs.isEmpty) break;
      final batch = firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await masjidRef.delete();
    await logoutCurrentMasjid();
    await AuthService().clearSession();
  }

  /// Hydrate from SharedPreferences and Firestore. Safe to call multiple
  /// times — a second call just re-snapshots the active doc.
  ///
  /// Order of operations:
  ///   1. Read the persisted id from SharedPreferences (or fall back to
  ///      [defaultMasjidId]).
  ///   2. Read the persisted name from SharedPreferences so the AppBar
  ///      has *something* to show on the very first frame.
  ///   3. Async-fetch the latest name from Firestore and broadcast.
  ///   4. If the doc doesn't exist yet, create it with the persisted
  ///      name (or the default) so future reads return a clean doc.
  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _id = prefs.getString(_kIdKey) ?? defaultMasjidId;
      _name = prefs.getString(_kNameKey) ?? defaultMasjidName;
      _nameBangla = prefs.getString(_kNameBanglaKey) ?? _name;
      _nameEnglish = prefs.getString(_kNameEnglishKey) ?? _name;
      final storedProfiles = prefs.getString(_kProfilesKey);
      if (storedProfiles != null) {
        final decoded = jsonDecode(storedProfiles);
        if (decoded is List) {
          _profiles = decoded
              .whereType<Map>()
              .map(
                (profile) => profile.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ),
              )
              .where((profile) => profile['token']?.isNotEmpty == true)
              .toList();
        }
      }
      if (_id != defaultMasjidId &&
          !_profiles.any((profile) => profile['token'] == _id)) {
        _profiles.add({
          'token': _id,
          'nameBangla': _nameBangla,
          'nameEnglish': _nameEnglish,
        });
      }
    } catch (_) {
      // SharedPreferences is best-effort — defaults are fine.
    }
    notifyListeners();

    if (!hasActiveMasjid) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('masjids')
          .doc(_id)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        final banglaName = (data['nameBangla'] as String?)?.trim();
        final englishName = (data['nameEnglish'] as String?)?.trim();
        final legacyName = (data['name'] as String?)?.trim();
        final remoteName = englishName?.isNotEmpty == true
            ? englishName
            : (legacyName?.isNotEmpty == true ? legacyName : null);
        if (banglaName?.isNotEmpty == true) _nameBangla = banglaName!;
        if (remoteName != null) _nameEnglish = remoteName;
        _name = _nameEnglish;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kNameBanglaKey, _nameBangla);
          await prefs.setString(_kNameEnglishKey, _nameEnglish);
        } catch (_) {}
        if (remoteName != null &&
            remoteName.isNotEmpty &&
            remoteName != _name) {
          _name = remoteName;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kNameKey, _name);
          } catch (_) {}
          notifyListeners();
        }

        final updates = <String, dynamic>{
          if (data['token'] != _id) 'token': _id,
          if (data['createdAt'] == null)
            'createdAt': FieldValue.serverTimestamp(),
          if (banglaName == null || banglaName.isEmpty)
            'nameBangla': _nameBangla,
          if (englishName == null || englishName.isEmpty)
            'nameEnglish': remoteName ?? _name,
        };
        if (updates.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('masjids')
              .doc(_id)
              .set(updates, SetOptions(merge: true));
        }
      }
    } catch (_) {
      // Offline / permission denied — keep the cached name. UI will
      // still render, just with the previously-saved string.
    }
  }

  /// Update the masjid name. Persists to Firestore (the source of
  /// truth) and to SharedPreferences (the offline cache) so the AppBar
  /// updates instantly on this device and stays consistent on others.
  Future<void> setMasjidName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == _name) return;

    _name = trimmed;
    notifyListeners();

    // Local cache first so the UI can rebuild without waiting on network.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNameKey, _name);
    } catch (_) {}

    // Then push to Firestore — failures are caught because the local
    // cache is already consistent, and a retry will happen on next
    // launch.
    try {
      await FirebaseFirestore.instance.collection('masjids').doc(_id).set({
        'name': _name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Test/utility hook — only flips the in-memory id. Not surfaced in
  /// the UI today; useful for future "switch masjid" flows.
  Future<void> setMasjidId(String newId) async {
    final trimmed = newId.trim();
    if (trimmed.isEmpty || trimmed == _id) return;
    _id = trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kIdKey, _id);
    } catch (_) {}
    notifyListeners();
    await hydrate();
  }
}

/// InheritedNotifier wrapper so any widget that calls
/// `MasjidScope.of(context)` will rebuild when the masjid name changes.
class MasjidScope extends InheritedNotifier<MasjidService> {
  const MasjidScope({
    super.key,
    required MasjidService service,
    required super.child,
  }) : super(notifier: service);

  static MasjidService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MasjidScope>();
    assert(scope != null, 'MasjidScope missing from widget tree');
    return scope!.notifier!;
  }
}
