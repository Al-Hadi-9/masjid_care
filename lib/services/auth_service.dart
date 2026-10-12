import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'masjid_service.dart';

class AuthService {
  static const _sessionKey = 'database_admin_session';

  Future<Map<String, String>> loginDatabase(
    String identifier,
    String password,
  ) async {
    final rawIdentifier = identifier.trim();
    final value = rawIdentifier.contains('@')
        ? rawIdentifier.toLowerCase()
        : rawIdentifier;
    final field = value.contains('@') ? 'email' : 'phone';
    final admins = FirebaseFirestore.instance
        .collection('admins')
        .where(field, isEqualTo: value)
        .where('masjidToken', isEqualTo: MasjidService.instance.masjidId)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    var snapshot = await admins;
    var isSupervisory = false;
    if (snapshot.docs.isEmpty) {
      snapshot = await FirebaseFirestore.instance
          .collection('supervisory_admin')
          .where(field, isEqualTo: value)
          .limit(1)
          .get();
      isSupervisory = snapshot.docs.isNotEmpty;
    }
    if (snapshot.docs.isEmpty) {
      throw StateError('Admin account was not found or is not approved.');
    }
    final data = snapshot.docs.first.data();
    final status = data['status'];
    if (isSupervisory &&
        status != null &&
        status != 'approved' &&
        status != 'approve' &&
        status != 'accept') {
      throw StateError('Supervisory admin account is not approved.');
    }
    final expected = data['passwordHash'] as String?;
    final passwordMatchesDatabase =
        expected != null && expected == hashPassword(password);
    if (!passwordMatchesDatabase) {
      if (field != 'email') throw StateError('Invalid admin password.');
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: value.toLowerCase(),
        password: password,
      );
      final authenticatedUser = credential.user;
      final storedUid = (data['authUid'] ?? '').toString();
      if (authenticatedUser == null ||
          storedUid.isEmpty ||
          authenticatedUser.uid != storedUid) {
        throw StateError('Email or password is incorrect.');
      }
      await snapshot.docs.first.reference.update({
        'passwordHash': hashPassword(password),
      });
    }
    var authUid = (data['authUid'] ?? '').toString();
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null &&
        authUser.email?.trim().toLowerCase() ==
            (data['email'] ?? '').toString().trim().toLowerCase()) {
      authUid = authUser.uid;
    }
    final session = <String, String>{
      'name': (data['name'] ?? 'Admin').toString(),
      'phone': (data['phone'] ?? '').toString(),
      'email': (data['email'] ?? '').toString(),
      'masjidToken': (data['masjidToken'] ?? '').toString(),
      'role': isSupervisory ? 'supervisory_admin' : 'admin',
      if (authUid.isNotEmpty) 'authUid': authUid,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session));
    return session;
  }

  Future<void> logout() async {
    await clearSession();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await GoogleSignIn(
        serverClientId:
            '504237878904-oln13p99i6aer0q7du3l4l88ohk04bmt.apps.googleusercontent.com',
      ).signOut();
    }
    await FirebaseAuth.instance.signOut();
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> deleteCurrentAdminAccount({String password = ''}) async {
    final session = await currentSession();
    final masjidToken = session?['masjidToken'];
    if (session == null || masjidToken == null) {
      throw StateError('Sign in again before deleting this admin account.');
    }
    if (session['role'] == 'supervisory_admin') {
      throw StateError('Delete supervisory accounts from account management.');
    }
    final adminQuery = await FirebaseFirestore.instance
        .collection('admins')
        .where('masjidToken', isEqualTo: masjidToken)
        .where('email', isEqualTo: session['email'] ?? '')
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    if (adminQuery.docs.isEmpty) {
      throw StateError('Could not verify this admin account.');
    }
    if (adminQuery.docs.first.data()['isOwner'] == true) {
      throw StateError(
        'The masjid creator must delete the masjid before deleting their account.',
      );
    }

    // This action removes the app's admin record only. Firebase Auth remains
    // untouched, so the person can use the same sign-in account elsewhere.
    await adminQuery.docs.first.reference.delete();
    await clearSession();
  }


  Future<Map<String, String>> loginGoogleAdmin(String email) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        user.email?.trim().toLowerCase() != email.trim().toLowerCase() ||
        !user.providerData.any(
          (provider) => provider.providerId == 'google.com',
        )) {
      throw StateError('Sign in with the Google account linked to this admin.');
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('admins')
        .where('authUid', isEqualTo: user.uid)
        .where('masjidToken', isEqualTo: MasjidService.instance.masjidId)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw StateError('This Google account is not an approved admin.');
    }
    final data = snapshot.docs.first.data();
    final session = <String, String>{
      'name': (data['name'] ?? 'Admin').toString(),
      'phone': (data['phone'] ?? '').toString(),
      'email': (data['email'] ?? email).toString(),
      'masjidToken': (data['masjidToken'] ?? '').toString(),
      'role': 'admin',
      'authUid': user.uid,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session));
    return session;
  }

  Future<void> saveDatabaseSession({
    required String name,
    required String phone,
    required String email,
    required String masjidToken,
    String? authUid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'masjidToken': masjidToken,
        'role': 'admin',
        if (authUid != null) 'authUid': authUid,
      }),
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      provider.setCustomParameters({'prompt': 'select_account'});
      // Keep the OAuth result in the current page. Mobile browsers can
      // partition sessionStorage during a redirect and lose Firebase's
      // initial OAuth state.
      return FirebaseAuth.instance.signInWithPopup(provider);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final googleSignIn = GoogleSignIn(
        serverClientId:
            '504237878904-oln13p99i6aer0q7du3l4l88ohk04bmt.apps.googleusercontent.com',
      );
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'sign-in-cancelled',
          message: 'Google account selection was cancelled.',
        );
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message:
              'Google did not return an ID token. Check the Android SHA-1 in Firebase settings.',
        );
      }
      return FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        ),
      );
    }
    return FirebaseAuth.instance.signInWithProvider(provider);
  }

  Future<UserCredential?> getGoogleRedirectResult() async {
    if (!kIsWeb) return null;
    return FirebaseAuth.instance.getRedirectResult();
  }

  Future<void> sendEmailVerificationLink({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isValidEmail(cleanEmail)) {
      throw ArgumentError('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters.');
    }
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code != 'email-already-in-use') rethrow;
      credential = await auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    }
    final user = credential.user;
    if (user == null) {
      throw StateError('Could not create the email authentication account.');
    }
    if (displayName?.trim().isNotEmpty == true) {
      await user.updateDisplayName(displayName!.trim());
    }
    await user.sendEmailVerification();
  }

  Future<void> sendPasswordResetLink(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isValidEmail(cleanEmail)) {
      throw ArgumentError('Enter a valid email address.');
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
  }

  Future<bool> refreshEmailVerification(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isValidEmail(cleanEmail)) {
      throw ArgumentError('Enter a valid email address.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (user.email?.trim().toLowerCase() != cleanEmail) return false;
    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;
    return refreshedUser?.email?.trim().toLowerCase() == cleanEmail &&
        (refreshedUser?.emailVerified ?? false);
  }

  static bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  Future<Map<String, String>?> currentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return Map<String, String>.from(decoded as Map);
  }

  static String hashPassword(String password) =>
      sha256.convert(utf8.encode(password)).toString();
}
