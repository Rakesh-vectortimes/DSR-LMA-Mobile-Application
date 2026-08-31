import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/permissions/record_permissions.dart';
import '../data/auth_repository.dart';
import '../data/models/user.dart';

enum AuthStatus {
  unknown,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.authenticated(User user)
      : this(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated({String? errorMessage})
      : this(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  const AuthState.error(String message)
      : this(status: AuthStatus.error, errorMessage: message);

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get canCreateReports => canWriteReports;
  bool get canWriteReports => user?.canWriteReports ?? false;
  bool get canViewReports => user?.canViewReports ?? false;
  bool get showLmaSettings => user?.showLmaSettings ?? false;
  bool get isClientUser => user?.isClientUser ?? false;
  bool get showCompanyOrganizationFilter =>
      (user?.companyType == null || user?.companyType == 'parent');

  bool canEditRecord({
    String? createdByRole,
    String? creatorRole,
    dynamic createdBy,
  }) {
    return RecordPermissions.canEditRecord(
      user: user,
      createdByRole: createdByRole,
      creatorRole: creatorRole,
      createdBy: createdBy,
    );
  }

  bool canDeleteRecord({
    String? createdByRole,
    String? creatorRole,
    dynamic createdBy,
  }) {
    return RecordPermissions.canDeleteRecord(
      user: user,
      createdByRole: createdByRole,
      creatorRole: creatorRole,
      createdBy: createdBy,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState.unknown()) {
    _ref.read(sessionExpiredHandlerProvider).bind(onSessionExpired);
  }

  final Ref _ref;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  /// Splash: restore session from secure storage via `/auth/me`.
  /// Dio interceptor refreshes once on 401; failed refresh clears session.
  Future<void> restoreSession() async {
    state = const AuthState.loading();
    try {
      final access = await _repo.readAccessToken();
      if (access == null || access.isEmpty) {
        state = const AuthState.unauthenticated();
        return;
      }

      final user = await _repo.me();
      state = AuthState.authenticated(user);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _repo.clearSession();
        state = const AuthState.unauthenticated();
        return;
      }
      // Keep tokens on network/server errors so the next launch can restore.
      state = AuthState.unauthenticated(errorMessage: e.message);
    } catch (_) {
      state = const AuthState.unauthenticated(
        errorMessage: 'Unable to restore session. Please try again.',
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final tokens = await _repo.login(email: email, password: password);
      await _repo.saveSession(tokens);

      final user = tokens.user ?? await _repo.me();
      state = AuthState.authenticated(user);
    } on ApiException catch (e) {
      state = AuthState.error(e.message);
    } catch (_) {
      state = const AuthState.error('Unable to sign in. Please try again.');
    }
  }

  Future<void> logout() async {
    state = const AuthState.loading();
    await _repo.logout();
    state = const AuthState.unauthenticated();
  }

  /// Called by Dio interceptor when refresh fails.
  void onSessionExpired() {
    if (state.status == AuthStatus.unauthenticated) return;
    state = const AuthState.unauthenticated();
  }

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState.unauthenticated();
    } else if (state.status == AuthStatus.unauthenticated &&
        state.errorMessage != null) {
      state = const AuthState.unauthenticated();
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
