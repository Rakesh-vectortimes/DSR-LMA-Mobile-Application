import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

/// Restores session via secure tokens + GET /auth/me.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 72,
              color: AppColors.onPrimary.withOpacity(0.95),
            ),
            const SizedBox(height: 20),
            Text(
              'DSR & LMA',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.onPrimary,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Diagnostic studies & lean maturity',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onPrimary.withOpacity(0.85),
                  ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
