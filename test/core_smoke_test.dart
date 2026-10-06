import 'package:flutter_test/flutter_test.dart';

import 'package:dsr_lma/core/constants/report_status.dart';
import 'package:dsr_lma/core/network/api_response.dart';

void main() {
  group('ReportStatus', () {
    test('parses integers and legacy strings', () {
      expect(ReportStatus.parse(1), ReportStatus.draft);
      expect(ReportStatus.parse(2), ReportStatus.published);
      expect(ReportStatus.parse(3), ReportStatus.archived);
      expect(ReportStatus.parse('1'), ReportStatus.draft);
      expect(ReportStatus.parse('draft'), ReportStatus.draft);
      expect(ReportStatus.parse('published'), ReportStatus.published);
      expect(ReportStatus.parse('submitted'), ReportStatus.published);
      expect(ReportStatus.parse('archived'), ReportStatus.archived);
      expect(ReportStatus.parse(null), ReportStatus.draft);
    });

    test('create/update payload sends integers', () {
      expect(ReportStatus.toApi(ReportStatus.draft), 1);
      expect(ReportStatus.toApi('submitted'), 2);
      expect(ReportStatus.toApi('published'), 2);
      expect(ReportStatus.toApi('archived'), 3);
    });

    test('list filter sends integers and omits all', () {
      expect(ReportStatus.toApiFilter('submitted'), 2);
      expect(ReportStatus.toApiFilter(1), 1);
      expect(ReportStatus.toApiFilter('all'), isNull);
      expect(ReportStatus.toApiFilter(null), isNull);
      expect(ReportStatus.toApiFilter(''), isNull);
    });

    test('prefers status_label for display', () {
      expect(ReportStatus.labelOf(2), 'Published');
      expect(
        ReportStatus.labelOf(1, statusLabel: 'Draft'),
        'Draft',
      );
      expect(
        ReportStatus.labelFromJson({'status': 2, 'status_label': 'Published'}),
        'Published',
      );
    });
  });

  group('ApiResponse', () {
    test('parses envelope', () {
      final res = ApiResponse<Map<String, dynamic>>.fromJson(
        {
          'success': true,
          'message': 'ok',
          'data': {'id': 1},
        },
        (json) => json as Map<String, dynamic>,
      );
      expect(res.success, isTrue);
      expect(res.message, 'ok');
      expect(res.data?['id'], 1);
    });
  });
}
