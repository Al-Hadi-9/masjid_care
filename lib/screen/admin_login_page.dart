import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_appbar.dart';
import 'admin_dashboard_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  bool hidePassword = true;

  String _errorText(Object error) {
    if (error is PlatformException && error.code == 'network_error') {
      return SettingsService.instance.isBangla
          ? 'Google-এ সংযোগ করা যায়নি। ইন্টারনেট ও Google Play services পরীক্ষা করে আবার চেষ্টা করুন।'
          : 'Google could not connect. Check your internet and Google Play services, then try again.';
    }
    if (error is StateError) {
      return error.message;
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid input.';
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'sign-in-cancelled':
        case 'popup-closed-by-user':
          return 'Google sign-in was cancelled.';
        default:
          return error.message ?? 'Google sign-in failed (${error.code}).';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _showError(Object error, {String title = 'Login failed'}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(_errorText(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _restoreGoogleRedirect();
  }

  Future<void> _restoreGoogleRedirect() async {
    try {
      final credential = await _authService.getGoogleRedirectResult();
      final user = credential?.user;
      if (user?.email != null) {
        await _finishGoogleAdminLogin(user!.email!);
      }
    } catch (error) {
      await _showError(error, title: 'Google admin login failed');
    }
  }

  Future<void> _finishGoogleAdminLogin(String email) async {
    final session = await _authService.loginGoogleAdmin(email);
    AdminService.instance.setCurrentAdminName(
      session['name'] ?? 'Admin',
      email: session['email'] ?? email,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
    );
  }

  Future<void> loginWithGoogle() async {
    try {
      setState(() => loading = true);
      final credential = await _authService.signInWithGoogle();
      final user = credential.user;
      if (user?.email == null) {
        throw StateError('Google account email was not found.');
      }
      await _finishGoogleAdminLogin(user!.email!);
    } catch (error) {
      await _showError(error, title: 'Google admin login failed');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> login() async {
    try {
      setState(() => loading = true);
      final session = await _authService.loginDatabase(
        emailController.text.trim(),
        passwordController.text.trim(),
      );
      AdminService.instance.setCurrentAdminName(
        session['name'] ?? 'Admin',
        email: session['email'] ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } catch (error) {
      await _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sendPasswordReset({String? targetEmail}) async {
    final email = (targetEmail ?? emailController.text).trim();
    if (email.isEmpty) {
      await _showError(
        ArgumentError('Enter your email first, then request a password reset.'),
        title: SettingsService.instance.isBangla
            ? 'পাসওয়ার্ড রিসেট'
            : 'Reset password',
      );
      return;
    }
    try {
      setState(() => loading = true);
      await _authService.sendPasswordResetLink(email);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            SettingsService.instance.isBangla
                ? 'রিসেট ইমেইল পাঠানো হয়েছে'
                : 'Reset email sent',
          ),
          content: Text(
            SettingsService.instance.isBangla
                ? 'আপনার Gmail-এর inbox-এ Firebase-এর password reset link পাঠানো হয়েছে। Gmail থেকে পাসওয়ার্ড বদলে নতুন পাসওয়ার্ড দিয়ে লগইন করুন।'
                : 'Firebase sent a password reset link to your Gmail. Reset your password from Gmail, then log in with the new password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      await _showError(
        error,
        title: SettingsService.instance.isBangla
            ? 'পাসওয়ার্ড রিসেট ব্যর্থ'
            : 'Password reset failed',
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showAlreadyRegistered(String email) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          SettingsService.instance.isBangla
              ? 'অ্যাকাউন্ট আগে থেকেই আছে'
              : 'Account already registered',
        ),
        content: Text(
          SettingsService.instance.isBangla
              ? 'এই মসজিদে আপনার account admin হিসেবে আগে থেকেই নিবন্ধিত। পাসওয়ার্ড ভুলে গেলে Gmail-এ reset link পাঠান।'
              : 'Your account is already registered as an admin for this masjid. If you forgot your password, send a reset link to your Gmail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(SettingsService.instance.isBangla ? 'বন্ধ' : 'Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _sendPasswordReset(targetEmail: email);
            },
            child: Text(
              SettingsService.instance.isBangla
                  ? 'পাসওয়ার্ড রিসেট'
                  : 'Reset password',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> requestAdmin() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    bool googleVerified = false;
    bool emailVerified = false;
    bool verificationLinkSent = false;
    bool verificationStep = false;
    final form = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          title: Text(
            verificationStep ? 'Email Verification' : 'Request admin access',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (verificationStep) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!verificationLinkSent) ...[
                            const Text(
                              'Send the verification link to your email.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () async {
                                try {
                                  await AuthService().sendEmailVerificationLink(
                                    email: email.text,
                                    password: password.text,
                                    displayName: name.text,
                                  );
                                  if (!dialogContext.mounted) return;
                                  dialogSetState(() {
                                    emailVerified = false;
                                    verificationLinkSent = true;
                                  });
                                } catch (error) {
                                  if (dialogContext.mounted) {
                                    await showDialog<void>(
                                      context: dialogContext,
                                      builder: (errorContext) => AlertDialog(
                                        title: const Text('Email verification'),
                                        content: Text(_errorText(error)),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(errorContext),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.email_outlined),
                              label: const Text('Send verification link'),
                            ),
                          ] else ...[
                            const Text(
                              'A verification link has been sent to this Gmail. Verify your account from Gmail, then come back and check.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final verified = await AuthService()
                                      .refreshEmailVerification(email.text);
                                  if (!dialogContext.mounted) return;
                                  if (verified) {
                                    dialogSetState(() => emailVerified = true);
                                    Navigator.pop(dialogContext, true);
                                  } else {
                                    await showDialog<void>(
                                      context: dialogContext,
                                      builder: (messageContext) => AlertDialog(
                                        content: const Text(
                                          'Your Gmail verification failed. Please verify the link from Gmail and try again.',
                                          textAlign: TextAlign.center,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(messageContext),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (!dialogContext.mounted) return;
                                  await showDialog<void>(
                                    context: dialogContext,
                                    builder: (messageContext) => AlertDialog(
                                      content: const Text(
                                        'Your Gmail verification failed. Please try again.',
                                        textAlign: TextAlign.center,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(messageContext),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              icon: Icon(
                                emailVerified
                                    ? Icons.check_circle
                                    : Icons.mark_email_read_outlined,
                              ),
                              label: Text(
                                emailVerified
                                    ? 'Email verified'
                                    : 'Check verification',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password *'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () {
                      if (name.text.trim().isEmpty ||
                          email.text.trim().isEmpty ||
                          password.text.length < 6) {
                        return;
                      }
                      dialogSetState(() => verificationStep = true);
                    },
                    child: const Text('Submit'),
                  ),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('OR'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final credential = await AuthService()
                            .signInWithGoogle();
                        final user = credential.user;
                        if (user?.email == null) {
                          throw StateError(
                            'Google account email was not found.',
                          );
                        }
                        email.text = user!.email!;
                        name.text = user.displayName ?? '';
                        if (!dialogContext.mounted) return;
                        dialogSetState(() => googleVerified = true);
                        Navigator.pop(dialogContext, true);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          await showDialog<void>(
                            context: dialogContext,
                            builder: (errorContext) => AlertDialog(
                              title: const Text('Google sign-in failed'),
                              content: Text(_errorText(error)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(errorContext),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.account_circle),
                    label: const Text('Continue with Google'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (verificationStep && verificationLinkSent) {
                  dialogSetState(() {
                    verificationLinkSent = false;
                    emailVerified = false;
                  });
                } else if (verificationStep) {
                  dialogSetState(() => verificationStep = false);
                } else {
                  Navigator.pop(dialogContext, false);
                }
              },
              child: Text(
                verificationStep && verificationLinkSent ? 'Back' : 'Cancel',
              ),
            ),
            if (verificationStep && !verificationLinkSent)
              TextButton(
                onPressed: () => dialogSetState(() => verificationStep = false),
                child: const Text('Back'),
              ),
          ],
        ),
      ),
    );
    if (form != true) return;
    try {
      await AdminService.instance.requestAdmin(
        name: name.text,
        phone: '',
        email: email.text,
        password: password.text,
        googleVerified: googleVerified,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (noticeContext) => AlertDialog(
          content: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mark_email_read_outlined,
                    color: Color(0xFF1B5E4E),
                    size: 38,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    SettingsService.instance.isBangla
                        ? 'ইমেইল যাচাই সম্পন্ন হয়েছে। অ্যাডমিন অনুমোদনের পর আপনি অ্যাডমিন হিসেবে কাজ করতে পারবেন।'
                        : 'Email verified. You can use the admin portal after an admin approves your request.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(noticeContext),
              child: Text(SettingsService.instance.isBangla ? 'ঠিক আছে' : 'OK'),
            ),
          ],
        ),
      ); // Creating an account signs the requester in automatically. A
      // pending requester must not enter the admin panel before approval.
      await _authService.logout();
    } catch (error) {
      if (error is StateError && error.message == 'ADMIN_ALREADY_REGISTERED') {
        await _showAlreadyRegistered(email.text);
        await _authService.logout();
      } else {
        await _showError(error, title: 'Admin access request failed');
      }
    } finally {
      name.dispose();
      email.dispose();
      password.dispose();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF1B5E4E);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppAppBar(
        title: AppAppBar.kMasjidName,
        subtitle: SettingsService.instance.isBangla
            ? 'অ্যাডমিন পোর্টাল'
            : 'Admin Portal',
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F4538), Color(0xFF1B5E4E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 50,
                        color: Color(0xFF008000),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Admin Portal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to manage masjid finances and records',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE8EEF1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email",
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: primary,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: primary,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: hidePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: primary,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: primary,
                                width: 1.6,
                              ),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => hidePassword = !hidePassword),
                              icon: Icon(
                                hidePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: loading
                                ? null
                                : () => _sendPasswordReset(),
                            child: Text(
                              SettingsService.instance.isBangla
                                  ? 'পাসওয়ার্ড ভুলে গেছেন?'
                                  : 'Forgot password?',
                              style: const TextStyle(color: primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: loading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    "Login",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : loginWithGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.account_circle,
                        color: Color(0xFF4285F4),
                      ),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: loading ? null : requestAdmin,
                    style: TextButton.styleFrom(foregroundColor: primary),
                    child: const Text(
                      'Request admin access',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
