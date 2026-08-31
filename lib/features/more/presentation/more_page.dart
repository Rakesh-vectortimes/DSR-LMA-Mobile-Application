import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/presentation/auth_controller.dart';

/// Profile hub and entry point for admin settings.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final loggingOut = auth.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user.name.isEmpty ? user.email : user.name),
              subtitle: Text(
                [
                  user.email,
                  if (user.role != null) user.role!,
                  if (user.companyType != null) user.companyType!,
                ].join(' · '),
              ),
            ),
          const Divider(),
          if (auth.showLmaSettings)
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('LMA Settings'),
              subtitle: const Text('Grades, sections, and questions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.lmaSettings),
            ),
          if (auth.showLmaSettings) const Divider(),
          ListTile(
            leading: loggingOut
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            title: const Text('Sign out'),
            enabled: !loggingOut,
            onTap: loggingOut
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
