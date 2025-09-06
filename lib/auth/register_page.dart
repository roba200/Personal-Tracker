import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toggleObscure() => setState(() => _obscure = !_obscure);

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showError(_mapCodeToMessage(e.code));
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapCodeToMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email already in use.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'operation-not-allowed':
        return 'Operation not allowed.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return 'Registration error ($code).';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
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
                  Icon(Icons.person_add_outlined,
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
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: spacing),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _register(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final value = v ?? '';
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: spacing * 1.5),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _register,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt),
                      label: Text(_loading ? 'Creating...' : 'Create account'),
                    ),
                  ),
                  const SizedBox(height: spacing),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to login'),
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

