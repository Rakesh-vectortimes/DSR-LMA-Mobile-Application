import 'package:flutter_test/flutter_test.dart';
import 'package:dsr_lma/core/permissions/record_permissions.dart';
import 'package:dsr_lma/features/auth/data/models/user.dart';

User _user({
  required String role,
  String? companyType,
  bool canWrite = true,
  bool isClient = false,
}) {
  return User(
    id: 'u1',
    name: 'User',
    email: 'u@example.com',
    role: role,
    companyType: companyType,
    canWriteReports: canWrite,
    isClientCompanyEmployee: isClient,
  );
}

void main() {
  group('RecordPermissions', () {
    test('client users cannot create or edit', () {
      final client = _user(role: 'employee', companyType: 'client', isClient: true);
      expect(RecordPermissions.canCreateRecord(client), isFalse);
      expect(
        RecordPermissions.canEditRecord(user: client, createdByRole: 'employee'),
        isFalse,
      );
    });

    test('super admin can edit all', () {
      final sa = _user(role: 'super_admin', companyType: 'parent');
      expect(
        RecordPermissions.canEditRecord(user: sa, createdByRole: 'super_admin'),
        isTrue,
      );
    });

    test('parent employee cannot edit super-admin records', () {
      final emp = _user(role: 'employee', companyType: 'parent');
      expect(
        RecordPermissions.canEditRecord(user: emp, createdByRole: 'super_admin'),
        isFalse,
      );
      expect(
        RecordPermissions.canEditRecord(user: emp, createdByRole: 'employee'),
        isTrue,
      );
    });

    test('child admin cannot edit super-admin records', () {
      final admin = _user(role: 'admin', companyType: 'child');
      expect(
        RecordPermissions.canEditRecord(user: admin, createdByRole: 'super_admin'),
        isFalse,
      );
      expect(
        RecordPermissions.canEditRecord(user: admin, createdByRole: 'employee'),
        isTrue,
      );
    });

    test('child employee cannot edit admin or super-admin records', () {
      final emp = _user(role: 'employee', companyType: 'child');
      expect(
        RecordPermissions.canEditRecord(user: emp, createdByRole: 'super_admin'),
        isFalse,
      );
      expect(
        RecordPermissions.canEditRecord(user: emp, createdByRole: 'admin'),
        isFalse,
      );
      expect(
        RecordPermissions.canEditRecord(user: emp, createdByRole: 'employee'),
        isTrue,
      );
    });
  });
}
