import '../../features/auth/data/models/user.dart';

/// Mirrors web `canEditRecord` / `canDeleteRecord` for DSR and LMA.
abstract final class RecordPermissions {
  static String? extractCreatorRole({
    String? createdByRole,
    String? creatorRole,
    dynamic createdBy,
  }) {
    if (createdByRole != null && createdByRole.trim().isNotEmpty) {
      return createdByRole.trim();
    }
    if (creatorRole != null && creatorRole.trim().isNotEmpty) {
      return creatorRole.trim();
    }
    if (createdBy is Map) {
      final role = createdBy['role'];
      if (role is String && role.trim().isNotEmpty) return role.trim();
    }
    return null;
  }

  static bool canCreateRecord(User? user) {
    if (user == null) return false;
    if (user.isClientUser) return false;
    return user.canWriteReports;
  }

  static bool canEditRecord({
    required User? user,
    String? createdByRole,
    String? creatorRole,
    dynamic createdBy,
  }) {
    if (user == null) return false;
    if (user.isClientUser) return false;
    if (user.role == 'super_admin') return true;

    final role = extractCreatorRole(
      createdByRole: createdByRole,
      creatorRole: creatorRole,
      createdBy: createdBy,
    );

    final isParentEmployee =
        user.role == 'employee' && (user.companyType == 'parent' || user.companyType == null);
    final isChildEmployee =
        user.role == 'employee' && user.companyType == 'child';

    if (isParentEmployee) {
      return role != 'super_admin';
    }
    if (isChildEmployee) {
      return role != 'admin' && role != 'super_admin';
    }
    if (user.role == 'admin') {
      return role != 'super_admin';
    }
    return false;
  }

  static bool canDeleteRecord({
    required User? user,
    String? createdByRole,
    String? creatorRole,
    dynamic createdBy,
  }) {
    return canEditRecord(
      user: user,
      createdByRole: createdByRole,
      creatorRole: creatorRole,
      createdBy: createdBy,
    );
  }
}
