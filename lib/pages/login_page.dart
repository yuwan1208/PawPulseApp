import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/pawpulse_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isSigningIn = false;

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSigningIn = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email address.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = e.message ?? 'Unable to sign in. Please try again.';
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
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: PawPulseTheme.primaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // PawPulse Logo
                    Image.asset('assets/pawpulse.png', height: 105),

                    const SizedBox(height: 12),

                    Text(
                      'PawPulse',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 54,
                        color: PawPulseTheme.darkNavy,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Smart care for happy paws.',
                      style: TextStyle(
                        fontSize: 16,
                        color: PawPulseTheme.darkNavy,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Login Card
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
                              'Welcome Back!',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: PawPulseTheme.darkNavy,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Sign in to continue caring for your pets.',
                              style: TextStyle(
                                fontSize: 13,
                                color: PawPulseTheme.secondaryGray,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Email
                            const Text(
                              'Email Address',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 9),

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

                                if (!value.contains('@')) {
                                  return 'Please enter a valid email.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Password
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 9),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isSigningIn) signIn();
                              },
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
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

                                return null;
                              },
                            ),

                            const SizedBox(height: 28),

                            // Sign In Button
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isSigningIn ? null : signIn,
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
                                child: _isSigningIn
                                    ? const SizedBox(
                                        height: 23,
                                        width: 23,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: PawPulseTheme.darkNavy,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 25),

                            // Register Link
                            Center(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: PawPulseTheme.secondaryGray,
                                    fontSize: 14,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Not a member? '),
                                    TextSpan(
                                      text: 'Register now',
                                      style: TextStyle(
                                        color: PawPulseTheme.darkNavy,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

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
