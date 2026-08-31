import 'package:flutter_test/flutter_test.dart';

import 'package:dsr_lma/core/constants/report_status.dart';
import 'package:dsr_lma/core/network/api_response.dart';

void main() {
  group('ReportStatusMapper', () {
    test('maps submitted ↔ published', () {
      expect(ReportStatusMapper.toApi('submitted'), 'published');
      expect(ReportStatusMapper.toUi('published'), 'submitted');
      expect(ReportStatusMapper.toApi('draft'), 'draft');
    });

    test('list filter rewrites submitted to published', () {
      expect(ReportStatusMapper.toApiFilter('submitted'), 'published');
      expect(ReportStatusMapper.toApiFilter('all'), isNull);
      expect(ReportStatusMapper.toApiFilter(null), isNull);
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
