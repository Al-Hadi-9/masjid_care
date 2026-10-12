import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../services/masjid_service.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import 'app_shell.dart';

class MasjidLoginPage extends StatefulWidget {
  const MasjidLoginPage({super.key});

  @override
  State<MasjidLoginPage> createState() => _MasjidLoginPageState();
}

class _MasjidLoginPageState extends State<MasjidLoginPage> {
  final _tokenController = TextEditingController();
  final _banglaController = TextEditingController();
  final _englishController = TextEditingController();
  final _creatorNameController = TextEditingController();
  final _creatorEmailController = TextEditingController();
  final _creatorPasswordController = TextEditingController();
  bool _loading = false;
  bool _googleVerified = false;
  bool _emailVerified = false;
  bool _verificationLinkSent = false;
  bool _hideCreatorPassword = true;
  bool _showCredentialStep = false;
  bool _showVerificationStep = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _banglaController.dispose();
    _englishController.dispose();
    _creatorNameController.dispose();
    _creatorEmailController.dispose();
    _creatorPasswordController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    await _run(() => MasjidService.instance.joinMasjid(_tokenController.text));
  }

  Future<void> _create() async {
    await _run(() async {
      final creator = FirebaseAuth.instance.currentUser;
      if (creator == null ||
          creator.email?.trim().toLowerCase() !=
              _creatorEmailController.text.trim().toLowerCase()) {
        throw StateError('Authenticate with the account used for credentials.');
      }
      final token = await MasjidService.instance.createMasjid(
        nameBangla: _banglaController.text,
        nameEnglish: _englishController.text,
        creatorName: _creatorNameController.text,
        creatorEmail: _creatorEmailController.text,
        creatorUid: creator.uid,
        creatorPassword: _creatorPasswordController.text,
      );
      await AuthService().saveDatabaseSession(
        name: _creatorNameController.text.trim(),
        phone: '',
        email: _creatorEmailController.text.trim(),
        masjidToken: token,
        authUid: creator.uid,
      );
      AdminService.instance.setCurrentAdminName(
        _creatorNameController.text,
        email: _creatorEmailController.text,
      );
      return token;
    });
  }

  Future<void> _run(Future<Object> Function() action) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showErrorCard(_messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'operation-not-allowed') {
        return 'Anonymous Authentication is disabled in Firebase. '
            'Enable it from Firebase Console > Authentication > Sign-in method.';
      }
      if (error.code == 'network-request-failed') {
        return 'Network connection failed. Check your internet and try again.';
      }
      return 'Authentication failed (${error.code}).';
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Firestore permission denied. Deploy the latest firestore.rules.';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'Firebase is temporarily unavailable. Check your internet and try again.';
      }
      return 'Firebase error (${error.code}).';
    }
    return 'Firebase connection failed. Please try again.';
  }

  String _verificationErrorMessage(Object error, String action) {
    if (error is PlatformException && error.code == 'network_error') {
      return 'Google could not connect. Check your internet and Google Play services, then try again.';
    }
    if (error is ArgumentError) {
      return error.toString().replaceFirst('Invalid argument(s): ', '');
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password does not match. Check them and try again.';
        case 'network-request-failed':
          return 'Masjid Care could not connect to the internet.';
        case 'operation-not-allowed':
          return 'Email verification is not enabled for Masjid Care yet.';
      }
    }
    return '$action failed. Please try again.';
  }

  Future<void> _showErrorCard(String message, {BuildContext? parentContext}) {
    final dialogContext = parentContext ?? context;
    return showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 52),
            const SizedBox(height: 12),
            const Text(
              'Masjid Care',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    _banglaController.clear();
    _englishController.clear();
    _creatorNameController.clear();
    _creatorEmailController.clear();
    _creatorPasswordController.clear();
    _googleVerified = false;
    _emailVerified = false;
    _verificationLinkSent = false;
    _hideCreatorPassword = true;
    _showCredentialStep = false;
    _showVerificationStep = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          alignment: Alignment.center,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
          contentPadding: EdgeInsets.fromLTRB(
            _showCredentialStep ? 20 : 24,
            0,
            _showCredentialStep ? 20 : 24,
            12,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
          title: Text(
            _showVerificationStep
                ? 'Email Verification'
                : _showCredentialStep
                ? 'Add Credentials'
                : 'Masjid Information',
            style: TextStyle(
              fontSize: _showVerificationStep
                  ? 20
                  : _showCredentialStep
                  ? 21
                  : 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          content: Theme(
            data: Theme.of(dialogContext).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: _showCredentialStep ? 18 : 12,
                ),
              ),
            ),
            child: SizedBox(
              width: _showCredentialStep ? 500 : 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_showCredentialStep) ...[
                    TextField(
                      controller: _banglaController,
                      decoration: const InputDecoration(
                        labelText: 'Masjid name (বাংলা)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _englishController,
                      decoration: const InputDecoration(
                        labelText: 'Masjid name (English)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else if (_showVerificationStep) ...[
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_verificationLinkSent) ...[
                              const Text(
                                'Send the verification link to your email.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _creatorEmailController.text.trim(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () async {
                                  try {
                                    await AuthService()
                                        .sendEmailVerificationLink(
                                          email: _creatorEmailController.text,
                                          password:
                                              _creatorPasswordController.text,
                                          displayName:
                                              _creatorNameController.text,
                                        );
                                    if (!dialogContext.mounted) return;
                                    dialogSetState(() {
                                      _emailVerified = false;
                                      _verificationLinkSent = true;
                                    });
                                  } on FirebaseAuthException catch (error) {
                                    if (!dialogContext.mounted) return;
                                    final message = switch (error.code) {
                                      'wrong-password' ||
                                      'invalid-credential' ||
                                      'user-not-found' =>
                                        'This email already has an account, but the password does not match. Reset the password, then return and send the verification link again.',
                                      'email-already-in-use' =>
                                        'This email already has an account. Use the correct password or another email.',
                                      'network-request-failed' =>
                                        'Masjid Care could not connect to the internet.',
                                      _ => _verificationErrorMessage(
                                        error,
                                        'Sending the verification link',
                                      ),
                                    };
                                    if (error.code == 'wrong-password' ||
                                        error.code == 'invalid-credential' ||
                                        error.code == 'user-not-found') {
                                      await showDialog<void>(
                                        context: dialogContext,
                                        builder: (messageContext) => AlertDialog(
                                          content: Text(
                                            message,
                                            textAlign: TextAlign.center,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(messageContext),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () async {
                                                try {
                                                  await AuthService()
                                                      .sendPasswordResetLink(
                                                        _creatorEmailController
                                                            .text,
                                                      );
                                                  if (!messageContext.mounted) {
                                                    return;
                                                  }
                                                  Navigator.pop(messageContext);
                                                  await _showErrorCard(
                                                    'Password reset link sent. Reset your password from Gmail, return to Add Credentials, then send the verification link again.',
                                                    parentContext:
                                                        dialogContext,
                                                  );
                                                } catch (resetError) {
                                                  if (!messageContext.mounted) {
                                                    return;
                                                  }
                                                  await _showErrorCard(
                                                    _verificationErrorMessage(
                                                      resetError,
                                                      'Sending the password reset link',
                                                    ),
                                                    parentContext:
                                                        messageContext,
                                                  );
                                                }
                                              },
                                              child: const Text(
                                                'Reset password',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      await _showErrorCard(
                                        message,
                                        parentContext: dialogContext,
                                      );
                                    }
                                  } catch (error) {
                                    if (!dialogContext.mounted) return;
                                    await _showErrorCard(
                                      _verificationErrorMessage(
                                        error,
                                        'Sending the verification link',
                                      ),
                                      parentContext: dialogContext,
                                    );
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
                                _creatorEmailController.text.trim(),
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
                                        .refreshEmailVerification(
                                          _creatorEmailController.text,
                                        );
                                    if (!dialogContext.mounted) return;
                                    if (verified) {
                                      dialogSetState(
                                        () => _emailVerified = true,
                                      );
                                      Navigator.pop(dialogContext);
                                      await _create();
                                    } else {
                                      await _showErrorCard(
                                        'Your Gmail verification failed. Please verify the link from Gmail and try again.',
                                        parentContext: dialogContext,
                                      );
                                    }
                                  } catch (error) {
                                    if (!dialogContext.mounted) return;
                                    await _showErrorCard(
                                      _verificationErrorMessage(
                                        error,
                                        'Checking email verification',
                                      ),
                                      parentContext: dialogContext,
                                    );
                                  }
                                },
                                icon: Icon(
                                  _emailVerified
                                      ? Icons.check_circle
                                      : Icons.mark_email_read_outlined,
                                ),
                                label: Text(
                                  _emailVerified
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
                      controller: _creatorNameController,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _creatorEmailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => dialogSetState(() {
                        _emailVerified = false;
                        _googleVerified = false;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _creatorPasswordController,
                      obscureText: _hideCreatorPassword,
                      decoration: InputDecoration(
                        labelText: 'Admin password (minimum 6 characters)',
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => dialogSetState(
                            () => _hideCreatorPassword = !_hideCreatorPassword,
                          ),
                          icon: Icon(
                            _hideCreatorPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (_creatorNameController.text.trim().isEmpty ||
                              _creatorEmailController.text.trim().isEmpty ||
                              _creatorPasswordController.text.length < 6) {
                            await _showErrorCard(
                              'Enter your name, email, and a password of at least 6 characters.',
                              parentContext: dialogContext,
                            );
                            return;
                          }
                          dialogSetState(() => _showVerificationStep = true);
                        },
                        child: const Text('Submit'),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            final authService = AuthService();
                            final enteredEmail = _creatorEmailController.text
                                .trim()
                                .toLowerCase();
                            final credential = await authService
                                .signInWithGoogle();
                            final user = credential.user;
                            if (user == null || user.email == null) {
                              throw StateError(
                                'Google account email was not found.',
                              );
                            }
                            final googleEmail = user.email!
                                .trim()
                                .toLowerCase();
                            if (enteredEmail.isNotEmpty &&
                                enteredEmail != googleEmail) {
                              throw StateError(
                                'Use Google sign-in with the same email address '
                                'that you verified.',
                              );
                            }
                            final displayName = user.displayName?.trim() ?? '';
                            if (displayName.isEmpty) {
                              throw StateError(
                                'This Google account does not have a profile name. '
                                'Enter your name manually.',
                              );
                            }
                            _creatorEmailController.text = user.email!;
                            _creatorPasswordController.clear();
                            dialogSetState(() {
                              _emailVerified = false;
                              _creatorNameController.text = displayName;
                              _googleVerified = true;
                            });
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Google account verified.'),
                                ),
                              );
                              Navigator.pop(dialogContext);
                              await _create();
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              final message =
                                  error is PlatformException &&
                                      error.code == 'network_error'
                                  ? 'Google sign-in could not connect. Check your internet and Google Play services, then try again.'
                                  : error is FirebaseAuthException
                                  ? switch (error.code) {
                                      'operation-not-allowed' =>
                                        'Google sign-in is not enabled for Masjid Care yet.',
                                      'unauthorized-domain' =>
                                        'This website domain is not authorized for Google sign-in in Firebase Authentication.',
                                      'popup-blocked' =>
                                        'Your browser blocked the Google sign-in window. Allow popups for this site and try again.',
                                      'popup-closed-by-user' =>
                                        'Google sign-in was closed before account selection finished.',
                                      _ =>
                                        'Google sign-in failed (${error.code}): ${error.message ?? 'Please try again.'}',
                                    }
                                  : 'Google sign-in failed: $error';
                              await _showErrorCard(
                                message,
                                parentContext: dialogContext,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.account_circle),
                        label: Text(
                          _googleVerified
                              ? 'Google account verified'
                              : 'Continue with Google',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_showVerificationStep && _verificationLinkSent) {
                  dialogSetState(() {
                    _verificationLinkSent = false;
                    _emailVerified = false;
                  });
                } else {
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(
                _showVerificationStep && _verificationLinkSent
                    ? 'Back'
                    : 'Cancel',
              ),
            ),
            if (_showCredentialStep)
              TextButton(
                onPressed: () =>
                    dialogSetState(() => _showCredentialStep = false),
                child: const Text('Back'),
              ),
            if (!_showCredentialStep)
              FilledButton(
                onPressed: () async {
                  if (_banglaController.text.trim().isEmpty ||
                      _englishController.text.trim().isEmpty) {
                    await _showErrorCard(
                      'Fill in both masjid names.',
                      parentContext: dialogContext,
                    );
                    return;
                  }
                  if (_googleVerified) {
                    Navigator.pop(dialogContext);
                    await _create();
                    return;
                  }
                  dialogSetState(() => _showCredentialStep = true);
                },
                child: const Text('Next'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                          color: const Color(
                            0xFF1B5E4E,
                          ).withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mosque_rounded,
                        size: 50,
                        color: Color(0xFF008000),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Masjid Care',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B5E4E),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Login to your masjid',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),
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
                          controller: _tokenController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Masjid token / credential',
                            hintText: '6-character token',
                            prefixIcon: const Icon(
                              Icons.key_rounded,
                              color: Color(0xFF1B5E4E),
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
                                color: Color(0xFF1B5E4E),
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _join,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E4E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text(
                              'Join a Masjid',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
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
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _showCreateDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B5E4E),
                        side: const BorderSide(
                          color: Color(0xFF1B5E4E),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text(
                        'Add New Masjid',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
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
