/// Login screen: email/password authentication using FirebaseAuth.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:personal_tracker/widgets/app_snackbar.dart';

/// Presents a form to sign in with email and password.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Toggles password field visibility.
  void _toggleObscure() => setState(() => _obscure = !_obscure);

  /// Attempts to authenticate with FirebaseAuth and navigates to `/home`
  /// when successful. Shows friendly error messages on failure.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      AppSnackbar.error(context, _mapCodeToMessage(e.code));
    } catch (e) {
      AppSnackbar.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Maps FirebaseAuth error codes to user-friendly messages.
  String _mapCodeToMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      default:
        return 'Authentication error ($code).';
    }
  }

  void _showError(String message) => AppSnackbar.error(context, message);

  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline,
                      size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: spacing * 1.5),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Email is required';
                      final emailRx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRx.hasMatch(value)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: spacing),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: _toggleObscure,
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (v) {
                      final value = v ?? '';
                      if (value.isEmpty) return 'Password is required';
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: spacing * 1.5),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _login,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_loading ? 'Signing in...' : 'Log In'),
                    ),
                  ),
                  const SizedBox(height: spacing),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final email = _emailController.text.trim();
                          if (email.isEmpty) {
                            _showError('Enter your email to reset.');
                            return;
                          }
                          try {
                            await FirebaseAuth.instance
                                .sendPasswordResetEmail(email: email);
                            if (!mounted) return;
                            AppSnackbar.success(
                                context, 'Password reset email sent.');
                          } on FirebaseAuthException catch (e) {
                            _showError(_mapCodeToMessage(e.code));
                          }
                        },
                        child: const Text('Forgot password?'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/register');
                        },
                        child: const Text('Create account'),
                      ),
                    ],
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
