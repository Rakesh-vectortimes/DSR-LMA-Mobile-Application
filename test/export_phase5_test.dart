import 'package:flutter_test/flutter_test.dart';

import 'package:dsr_lma/core/export/export_filename.dart';
import 'package:dsr_lma/features/companies/data/models/organization.dart';

void main() {
  group('filenameFromContentDisposition', () {
    test('prefers RFC 5987 filename*', () {
      expect(
        filenameFromContentDisposition(
          "attachment; filename=\"plain.pdf\"; filename*=UTF-8''Acme%20report.pdf",
        ),
        'Acme report.pdf',
      );
    });

    test('falls back to quoted filename', () {
      expect(
        filenameFromContentDisposition('attachment; filename="Acme report.docx"'),
        'Acme report.docx',
      );
    });
  });

  group('resolveExportFilename', () {
    test('uses Content-Disposition first', () {
      expect(
        resolveExportFilename(
          contentDisposition: 'attachment; filename="from-header.pdf"',
          fallback: 'constructed.pdf',
          lastResort: 'lma-1.pdf',
        ),
        'from-header.pdf',
      );
    });

    test('uses constructed fallback then last resort', () {
      expect(
        resolveExportFilename(
          contentDisposition: null,
          fallback: 'constructed.pdf',
          lastResort: 'lma-1.pdf',
        ),
        'constructed.pdf',
      );
      expect(
        resolveExportFilename(
          contentDisposition: '',
          fallback: '',
          lastResort: 'study-9.pdf',
        ),
        'study-9.pdf',
      );
    });
  });

  test('buildLmaExportFilename strips title suffix and formats date', () {
    expect(
      buildLmaExportFilename(
        companyName: 'Acme Lean Maturity Assessment',
        title: 'Acme Lean Maturity Assessment',
        reportDate: '2026-08-17',
        kind: ExportKind.pdf,
      ),
      'Acme lean maturity assessment report (august 17).pdf',
    );
  });

  test('buildDsrExportFilename uses period range without a space before paren', () {
    expect(
      buildDsrExportFilename(
        companyName: 'Acme',
        title: 'Acme Diagnostic Study',
        periodFrom: '2026-08-17',
        periodTo: '2026-08-17',
        kind: ExportKind.pdf,
      ),
      'Acme diagnostic study report(august 17 - august 17).pdf',
    );
  });

  test('typography defaults to Calibri / 15px', () {
    const settings = CompanyTypographySettings();
    expect(settings.resolvedPdfFontFamily, 'Calibri');
    expect(settings.resolvedPdfFontSize, '15px');
    expect(settings.resolvedWordFontFamily, 'Calibri');
    expect(settings.resolvedWordFontSize, '15px');
  });
}
