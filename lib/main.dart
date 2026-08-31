/// Application entry — loads env, wires Riverpod + router.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Switch to [AppEnv.prod] for release builds (or via --dart-define=APP_ENV=prod).
  const envName = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  final env = AppEnv.fromName(envName);
  await AppConfig.load(env);

  runApp(const ProviderScope(child: DsrLmaApp()));
}

class DsrLmaApp extends ConsumerWidget {
  const DsrLmaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'DSR & LMA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
