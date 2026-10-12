import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_page.dart';
import 'admin_login_page.dart';

class AdminAuthWrapper extends StatefulWidget {
  const AdminAuthWrapper({super.key});

  @override
  State<AdminAuthWrapper> createState() => _AdminAuthWrapperState();
}

class _AdminAuthWrapperState extends State<AdminAuthWrapper> {
  late final Future<Map<String, String>?> _session = _loadSession();

  Future<Map<String, String>?> _loadSession() async {
    final authService = AuthService();
    var session = await authService.currentSession();
    if (session == null) {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (email != null &&
          email.isNotEmpty &&
          user!.providerData.any(
            (provider) => provider.providerId == 'google.com',
          )) {
        try {
          session = await authService.loginGoogleAdmin(email);
        } on StateError {
          // A remembered Google account still has to be an approved admin.
          await FirebaseAuth.instance.signOut();
        }
      }
    }
    if (session != null) {
      AdminService.instance.setCurrentAdminName(
        session['name'] ?? 'Admin',
        email: session['email'] ?? '',
      );
    }
    return session;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? const AdminLoginPage()
            : const AdminDashboardPage();
      },
    );
  }
}
