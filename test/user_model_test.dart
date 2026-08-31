import 'package:flutter_test/flutter_test.dart';
import 'package:dsr_lma/features/auth/data/models/user.dart';

void main() {
  test('User.fromJson maps _id and DSR/LMA permission flags', () {
    final user = User.fromJson(const {
      '_id': 'abc123',
      'name': 'Test User',
      'email': 'test@example.com',
      'role': 'admin',
      'company_type': 'child',
      'can_write_reports': true,
      'can_view_reports': true,
      'show_lma_settings': true,
      'is_client_company_employee': false,
    });

    expect(user.id, 'abc123');
    expect(user.canWriteReports, isTrue);
    expect(user.canViewReports, isTrue);
    expect(user.showLmaSettings, isTrue);
    expect(user.isClientUser, isFalse);
  });

  test('User.fromJson falls back show_lma_settings for parent super_admin', () {
    final user = User.fromJson(const {
      'id': 'u1',
      'name': 'SA',
      'email': 'sa@example.com',
      'role': 'super_admin',
      'company_type': 'parent',
    });
    expect(user.showLmaSettings, isTrue);
    expect(user.canWriteReports, isTrue);
  });

  test('client users cannot write reports', () {
    final user = User.fromJson(const {
      'id': 'c1',
      'name': 'Client',
      'email': 'c@example.com',
      'role': 'employee',
      'company_type': 'client',
      'is_client_company_employee': true,
    });
    expect(user.isClientUser, isTrue);
    expect(user.canWriteReports, isFalse);
  });

  test('User.fromJson parses optional role/permission fields', () {
    final user = User.fromJson(const {
      'id': 'u2',
      'name': 'Pat',
      'email': 'p@example.com',
      'custom_role_id': 'role-9',
      'permissions': {'reports': ['read']},
      'permission_overrides': {'can_view_reports': true},
    });

    expect(user.customRoleId, 'role-9');
    expect(user.permissions, {'reports': ['read']});
    expect(user.permissionOverrides?['can_view_reports'], isTrue);
  });

  test('AuthTokens.fromJson includes nested user', () {
    final tokens = AuthTokens.fromJson(const {
      'access_token': 'a',
      'refresh_token': 'r',
      'token_type': 'bearer',
      'user': {
        'id': 'u1',
        'name': 'N',
        'email': 'n@e.com',
        'can_view_reports': true,
      },
    });

    expect(tokens.accessToken, 'a');
    expect(tokens.refreshToken, 'r');
    expect(tokens.user?.id, 'u1');
    expect(tokens.user?.canViewReports, isTrue);
  });
}
