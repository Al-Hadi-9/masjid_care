import 'package:cloud_firestore/cloud_firestore.dart';

import 'masjid_service.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  AdminService._();
  static final instance = AdminService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('admins');

  CollectionReference<Map<String, dynamic>> get _admins =>
      _firestore.collection('admins');

  Future<void> requestAdmin({
    required String name,
    required String phone,
    String? email,
    String password = '',
    bool googleVerified = false,
  }) async {
    if (MasjidService.instance.masjidId == MasjidService.defaultMasjidId) {
      throw StateError('Join a masjid before requesting admin access.');
    }
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final cleanEmail = email?.trim().toLowerCase() ?? '';
    final user = FirebaseAuth.instance.currentUser;
    if (cleanName.isEmpty ||
        cleanEmail.isEmpty ||
        user == null ||
        user.email?.trim().toLowerCase() != cleanEmail.toLowerCase() ||
        (!googleVerified && password.length < 6)) {
      throw ArgumentError('Name, email and valid credentials are required.');
    }
    final existing = await _admins
        .where('email', isEqualTo: cleanEmail)
        .where('masjidToken', isEqualTo: MasjidService.instance.masjidId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('ADMIN_ALREADY_REGISTERED');
    }
    final data = <String, dynamic>{
      'name': cleanName,
      'phone': cleanPhone,
      'email': cleanEmail,
      'authUid': user.uid,
      'status': 'pending',
      'masjidToken': MasjidService.instance.masjidId,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (googleVerified) {
      if (!user.providerData.any(
        (provider) => provider.providerId == 'google.com',
      )) {
        throw StateError('Sign in with Google before requesting admin access.');
      }
      data['authProvider'] = 'google';
    } else {
      await user.reload();
      if (!(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
        throw StateError('Verify your email before requesting admin access.');
      }
      data['passwordHash'] = AuthService.hashPassword(password);
    }
    await _admins.add(data);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingRequests() => _requests
      .where('masjidToken', isEqualTo: MasjidService.instance.masjidId)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  Future<bool> canApproveRequests() async {
    final session = await AuthService().currentSession();
    if (session == null) return false;
    if (session['role'] == 'supervisory_admin') return true;

    final approved = await _admins
        .where('masjidToken', isEqualTo: MasjidService.instance.masjidId)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    return approved.docs.isNotEmpty;
  }

  Future<void> decideRequest({
    required String requestId,
    required bool approve,
  }) async {
    final request = await _admins.doc(requestId).get();
    if (!request.exists) throw StateError('Admin request was not found.');
    final requestData = request.data()!;
    if (requestData['masjidToken'] != MasjidService.instance.masjidId) {
      throw StateError('This request belongs to another masjid.');
    }
    if (!await canApproveRequests()) {
      throw StateError('You are not allowed to approve this request.');
    }
    if (approve) {
      await _admins.doc(requestId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _admins.doc(requestId).delete();
    }
  }

  Future<bool> isApprovedAdmin() async {
    final session = await AuthService().currentSession();
    return session != null;
  }

  String get currentAdminName => _currentAdminName;
  String get currentAdminEmail => _currentAdminEmail;

  static String _currentAdminName = 'Admin';
  static String _currentAdminEmail = '';

  void setCurrentAdminName(String name, {String email = ''}) {
    _currentAdminName = name.trim().isEmpty ? 'Admin' : name.trim();
    _currentAdminEmail = email.trim();
  }
}
