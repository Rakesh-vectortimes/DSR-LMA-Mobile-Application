import 'package:equatable/equatable.dart';

import '../../../../core/network/list_response.dart';

/// Authenticated user + permission flags from `/auth/me` and login payload.
class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.mobileNumber,
    this.role,
    this.status,
    this.companyId,
    this.parentCompanyId,
    this.childCompanyId,
    this.clientCompanyId,
    this.companyType,
    this.canWriteReports = false,
    this.canViewReports = true,
    this.showLmaSettings = false,
    this.isClientCompanyEmployee = false,
    this.profileImage,
    this.digitalSignature,
    this.customRoleId,
    this.permissions,
    this.permissionOverrides,
  });

  final String id;
  final String name;
  final String email;
  final String? mobileNumber;
  final String? role;
  final String? status;
  final String? companyId;
  final String? parentCompanyId;
  final String? childCompanyId;
  final String? clientCompanyId;
  final String? companyType;
  final bool canWriteReports;
  final bool canViewReports;
  final bool showLmaSettings;
  final bool isClientCompanyEmployee;
  final String? profileImage;
  final String? digitalSignature;
  final String? customRoleId;
  final dynamic permissions;
  final Map<String, dynamic>? permissionOverrides;

  bool get isClientUser => isClientCompanyEmployee || companyType == 'client';

  factory User.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String?;
    final companyType = json['company_type'] as String?;
    final isClientCompanyEmployee = _asBool(json['is_client_company_employee']);
    final isClient = isClientCompanyEmployee || companyType == 'client';

    return User(
      id: _readId(json),
      name: (json['name'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      mobileNumber: json['mobile_number'] as String?,
      role: role,
      status: json['status'] as String?,
      companyId: normalizeEntityId(json['company_id']),
      parentCompanyId: normalizeEntityId(json['parent_company_id']),
      childCompanyId: normalizeEntityId(json['child_company_id']),
      clientCompanyId: normalizeEntityId(json['client_company_id']),
      companyType: companyType,
      canWriteReports: json.containsKey('can_write_reports')
          ? _asBool(json['can_write_reports'])
          : _defaultCanWriteReports(
              role: role,
              companyType: companyType,
              isClient: isClient,
            ),
      canViewReports: json.containsKey('can_view_reports')
          ? _asBool(json['can_view_reports'])
          : true,
      showLmaSettings: json.containsKey('show_lma_settings')
          ? _asBool(json['show_lma_settings'])
          : role == 'super_admin' && (companyType == 'parent' || companyType == null),
      isClientCompanyEmployee: isClientCompanyEmployee,
      profileImage: json['profile_image'] as String?,
      digitalSignature: json['digital_signature'] as String?,
      customRoleId: _asString(json['custom_role_id']),
      permissions: json['permissions'],
      permissionOverrides: _asStringKeyedMap(json['permission_overrides']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'mobile_number': mobileNumber,
        'role': role,
        'status': status,
        'company_id': companyId,
        'parent_company_id': parentCompanyId,
        'child_company_id': childCompanyId,
        'client_company_id': clientCompanyId,
        'company_type': companyType,
        'can_write_reports': canWriteReports,
        'can_view_reports': canViewReports,
        'show_lma_settings': showLmaSettings,
        'is_client_company_employee': isClientCompanyEmployee,
        'profile_image': profileImage,
        'digital_signature': digitalSignature,
        'custom_role_id': customRoleId,
        'permissions': permissions,
        'permission_overrides': permissionOverrides,
      };

  static String _readId(Map<String, dynamic> json) {
    return normalizeEntityId(json['id'] ?? json['_id'] ?? json['user_id']) ?? '';
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static bool _defaultCanWriteReports({
    required String? role,
    required String? companyType,
    required bool isClient,
  }) {
    if (isClient) return false;
    if (role == 'super_admin') {
      return companyType == 'parent' || companyType == null;
    }
    if (role == 'admin') return companyType == 'child';
    if (role == 'employee') {
      return companyType == 'parent' || companyType == 'child' || companyType == null;
    }
    return false;
  }

  @override
  List<Object?> get props => [
        id,
        email,
        role,
        companyId,
        canWriteReports,
        canViewReports,
        showLmaSettings,
        customRoleId,
      ];
}

/// Tokens (+ optional user) returned by login / refresh.
class AuthTokens extends Equatable {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'bearer',
    this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final User? user;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    return AuthTokens(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'bearer',
      user: userRaw is Map<String, dynamic>
          ? User.fromJson(userRaw)
          : userRaw is Map
              ? User.fromJson(Map<String, dynamic>.from(userRaw))
              : null,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, tokenType, user];
}
