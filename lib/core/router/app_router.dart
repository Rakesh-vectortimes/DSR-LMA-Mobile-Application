import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/dsr/presentation/dsr_form_page.dart';
import '../../features/dsr/presentation/dsr_list_page.dart';
import '../../features/dsr/presentation/dsr_preview_page.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/lma/presentation/lma_form_page.dart';
import '../../features/lma/presentation/lma_list_page.dart';
import '../../features/lma/presentation/lma_preview_page.dart';
import '../../features/lma/presentation/settings/lma_settings_page.dart';
import '../../features/more/presentation/more_page.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final onSplash = loc == AppRoutes.splash;
      final onLogin = loc == AppRoutes.login;

      switch (auth.status) {
        case AuthStatus.unknown:
          return onSplash ? null : AppRoutes.splash;
        case AuthStatus.loading:
          if (onSplash || onLogin) return null;
          return null;
        case AuthStatus.unauthenticated:
        case AuthStatus.error:
          return onLogin ? null : AppRoutes.login;
        case AuthStatus.authenticated:
          if (onSplash || onLogin) return AppRoutes.lma;
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.lmaCreate,
        builder: (context, state) => const LmaFormPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/lma/edit/:id',
        builder: (context, state) => LmaFormPage(
          assessmentId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/lma/:id',
        builder: (context, state) => LmaPreviewPage(
          assessmentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.dsrCreate,
        builder: (context, state) => const DsrFormPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/dsr/edit/:id',
        builder: (context, state) => DsrFormPage(
          studyId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/dsr/:id',
        builder: (context, state) => DsrPreviewPage(
          studyId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.lmaSettings,
        builder: (context, state) => const LmaSettingsPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.lma,
                builder: (context, state) => const LmaListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dsr,
                builder: (context, state) => const DsrListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (context, state) => const MorePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _subscription = _ref.listen<AuthState>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
