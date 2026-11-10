import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/pawpulse_theme.dart';

/// Profile Settings page for PawPulse.
///
/// Follows the Main Dashboard visual design (cyan-to-turquoise palette,
/// rounded cards, clean typography, soft gradients, and modern form controls).
///
/// Features:
/// - Profile header with user avatar, display name, and email
/// - Editable display name with validation
/// - Read-only email address & account creation metadata
/// - Password reset email trigger
/// - Logout with confirmation dialog
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _emailController;

  bool _isSavingName = false;
  bool _isSendingReset = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _displayNameController = TextEditingController(
      text: _currentUser?.displayName ?? '',
    );
    _emailController = TextEditingController(
      text: _currentUser?.email ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newName = _displayNameController.text.trim();
    setState(() => _isSavingName = true);

    try {
      await user.updateDisplayName(newName);
      await user.reload();
      if (!mounted) return;
      setState(() {
        _currentUser = FirebaseAuth.instance.currentUser;
        _isSavingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name updated successfully!'),
          backgroundColor: PawPulseTheme.darkNavy,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingName = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update name: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address associated with this account.')),
      );
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: PawPulseTheme.darkNavy,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: $e')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: PawPulseTheme.white,
        shape: RoundedRectangleBorder(borderRadius: PawPulseTheme.cardRadius),
        title: const Text(
          'Log Out',
          style: TextStyle(
            color: PawPulseTheme.darkNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of PawPulse?',
          style: TextStyle(color: PawPulseTheme.secondaryGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PawPulseTheme.secondaryGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: PawPulseTheme.buttonRadius,
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _currentUser?.displayName;
    final effectiveName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (_currentUser?.email?.split('@').first ?? 'Pet Owner');
    final initial = effectiveName.isNotEmpty ? effectiveName[0].toUpperCase() : 'P';

    return Scaffold(
      backgroundColor: PawPulseTheme.background,
      appBar: AppBar(
        backgroundColor: PawPulseTheme.turquoise,
        foregroundColor: PawPulseTheme.darkNavy,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: PawPulseTheme.darkNavy,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // ─── Header Card with Gradient ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: PawPulseTheme.primaryGradient,
                borderRadius: PawPulseTheme.cardRadius,
                boxShadow: [
                  BoxShadow(
                    color: PawPulseTheme.primaryCyan.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: PawPulseTheme.white,
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: PawPulseTheme.lightCyan,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: PawPulseTheme.darkNavy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    effectiveName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: PawPulseTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.email ?? 'No email associated',
                    style: TextStyle(
                      fontSize: 14,
                      color: PawPulseTheme.darkNavy.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: PawPulseTheme.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pets_rounded,
                          size: 14,
                          color: PawPulseTheme.darkNavy,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'PawPulse Pet Parent',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: PawPulseTheme.darkNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Card 1: Personal Details Form ────────────────────────────────
            Card(
              color: PawPulseTheme.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: PawPulseTheme.cardRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: PawPulseTheme.primaryCyan
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: PawPulseTheme.primaryCyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: PawPulseTheme.darkNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          labelStyle: const TextStyle(
                            color: PawPulseTheme.secondaryGray,
                          ),
                          prefixIcon: const Icon(
                            Icons.badge_outlined,
                            color: PawPulseTheme.secondaryGray,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PawPulseTheme.primaryCyan,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Display name cannot be empty';
                          }
                          if (value.trim().length < 2) {
                            return 'Display name must be at least 2 characters';
                          }
                          if (value.trim().length > 40) {
                            return 'Display name cannot exceed 40 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Email Address (Read-only)',
                          labelStyle: const TextStyle(
                            color: PawPulseTheme.secondaryGray,
                          ),
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: PawPulseTheme.secondaryGray,
                          ),
                          suffixIcon: const Icon(
                            Icons.lock_outline,
                            color: PawPulseTheme.secondaryGray,
                            size: 18,
                          ),
                          fillColor: Colors.grey.shade100,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PawPulseTheme.primaryCyan,
                            foregroundColor: PawPulseTheme.darkNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: PawPulseTheme.buttonRadius,
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isSavingName ? null : _saveDisplayName,
                          child: _isSavingName
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: PawPulseTheme.darkNavy,
                                  ),
                                )
                              : const Text(
                                  'Save Profile Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Card 2: Account Overview ─────────────────────────────────────
            Card(
              color: PawPulseTheme.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: PawPulseTheme.cardRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PawPulseTheme.primaryCyan
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: PawPulseTheme.primaryCyan,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Account Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: PawPulseTheme.darkNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      Icons.fingerprint,
                      'User ID',
                      _currentUser?.uid ?? 'N/A',
                      isMonospace: true,
                    ),
                    const Divider(height: 20),
                    _infoRow(
                      Icons.calendar_month_outlined,
                      'Member Since',
                      _formatDate(_currentUser?.metadata.creationTime),
                    ),
                    const Divider(height: 20),
                    _infoRow(
                      Icons.access_time_outlined,
                      'Last Sign In',
                      _formatDate(_currentUser?.metadata.lastSignInTime),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Card 3: Security & Session ───────────────────────────────────
            Card(
              color: PawPulseTheme.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: PawPulseTheme.cardRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PawPulseTheme.primaryCyan
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: PawPulseTheme.primaryCyan,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Security & Session',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: PawPulseTheme.darkNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PawPulseTheme.darkNavy,
                        side: const BorderSide(color: PawPulseTheme.lightCyan),
                        shape: RoundedRectangleBorder(
                          borderRadius: PawPulseTheme.buttonRadius,
                        ),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: _isSendingReset ? null : _sendPasswordReset,
                      icon: _isSendingReset
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mark_email_read_outlined, size: 20),
                      label: const Text(
                        'Send Password Reset Email',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: PawPulseTheme.buttonRadius,
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Log Out of PawPulse',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool isMonospace = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PawPulseTheme.secondaryGray),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: PawPulseTheme.secondaryGray,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PawPulseTheme.darkNavy,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

