import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

/// Real login against POST /auth/login.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final submitting = auth.status == AuthStatus.loading;
    final errorMessage =
        (auth.status == AuthStatus.error || auth.status == AuthStatus.unauthenticated)
            ? auth.errorMessage
            : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'DSR & LMA',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to continue',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    if (errorMessage != null && errorMessage.isNotEmpty) ...[
                      Material(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      enabled: !submitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        final email = v.trim();
                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (auth.errorMessage != null) {
                          ref.read(authControllerProvider.notifier).clearError();
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !submitting,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!submitting) _onSubmit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: submitting
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        return null;
                      },
                      onChanged: (_) {
                        if (auth.errorMessage != null) {
                          ref.read(authControllerProvider.notifier).clearError();
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: submitting ? null : _onSubmit,
                      child: submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign in'),
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
