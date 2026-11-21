import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/firestore_client.dart';
import '../theme/pawpulse_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isRegistering = false;

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRegistering = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Set a default display name from the email handle
        try {
          final defaultName = email.split('@').first;
          await user.updateDisplayName(defaultName);
          await user.reload();
        } catch (_) {}

        // Optionally create/sync a user profile document in Firestore
        try {
          await FirestoreClient.setDocument(
            collection: 'users',
            documentId: user.uid,
            firestoreFields: FirestoreClient.encodeFields({
              'uid': user.uid,
              'email': email,
              'displayName': user.displayName ?? email.split('@').first,
              'createdAt': FirestoreClient.nowTimestamp(),
            }),
          );
        } catch (dbError) {
          debugPrint('Optional Firestore user document creation notice: $dbError');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Welcome to PawPulse.'),
            backgroundColor: PawPulseTheme.darkNavy,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Return to root (MainPage) which automatically displays HomePage via authStateChanges
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists for this email address.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'The password is too weak. Please use at least 6 characters.';
          break;
        case 'operation-not-allowed':
          message = 'Email registration is currently not enabled.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = e.message ?? 'Registration failed. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: PawPulseTheme.secondaryGray),
      prefixIcon: Icon(icon, color: PawPulseTheme.primaryCyan),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: PawPulseTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: PawPulseTheme.primaryCyan.withValues(alpha: 0.20),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PawPulseTheme.primaryCyan, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: PawPulseTheme.primaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // PawPulse Logo
                    Image.asset('assets/pawpulse.png', height: 95),

                    const SizedBox(height: 10),

                    Text(
                      'PawPulse',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 50,
                        color: PawPulseTheme.darkNavy,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Create your pet care account.',
                      style: TextStyle(
                        fontSize: 15,
                        color: PawPulseTheme.darkNavy,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Registration Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: PawPulseTheme.white,
                        borderRadius: PawPulseTheme.cardRadius,
                        boxShadow: [
                          BoxShadow(
                            color: PawPulseTheme.darkNavy.withValues(
                              alpha: 0.12,
                            ),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join PawPulse',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: PawPulseTheme.darkNavy,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Enter your details to register a new account.',
                              style: TextStyle(
                                fontSize: 13,
                                color: PawPulseTheme.secondaryGray,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Email Address
                            const Text(
                              'Email Address',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                hint: 'Enter your email',
                                icon: Icons.email_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email.';
                                }

                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid email address.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            // Password
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                hint: 'Enter your password (min. 6 characters)',
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: PawPulseTheme.secondaryGray,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password.';
                                }

                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            // Confirm Password
                            const Text(
                              'Confirm Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isRegistering) register();
                              },
                              decoration: _inputDecoration(
                                hint: 'Re-enter your password',
                                icon: Icons.lock_reset_outlined,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordVisible =
                                          !_isConfirmPasswordVisible;
                                    });
                                  },
                                  icon: Icon(
                                    _isConfirmPasswordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: PawPulseTheme.secondaryGray,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password.';
                                }

                                if (value != _passwordController.text) {
                                  return 'Passwords do not match.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 26),

                            // Register Button
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isRegistering ? null : register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PawPulseTheme.primaryCyan,
                                  foregroundColor: PawPulseTheme.darkNavy,
                                  disabledBackgroundColor: PawPulseTheme
                                      .primaryCyan
                                      .withValues(alpha: 0.5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: PawPulseTheme.buttonRadius,
                                  ),
                                ),
                                child: _isRegistering
                                    ? const SizedBox(
                                        height: 23,
                                        width: 23,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: PawPulseTheme.darkNavy,
                                        ),
                                      )
                                    : const Text(
                                        'Register',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Back to Login Link
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      color: PawPulseTheme.secondaryGray,
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: PawPulseTheme.darkNavy,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'PawPulse • Your pet care companion',
                      style: TextStyle(
                        color: PawPulseTheme.darkNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
