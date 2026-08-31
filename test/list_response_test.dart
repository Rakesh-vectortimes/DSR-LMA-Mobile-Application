import 'package:flutter_test/flutter_test.dart';
import 'package:dsr_lma/core/network/list_response.dart';

void main() {
  group('ListResponse.extractItems', () {
    test('handles bare array', () {
      final items = ListResponse.extractItems(
        [
          {'_id': '1', 'name': 'Acme'},
          {'id': '2', 'name': 'Beta'},
        ],
        (json) => json,
      );
      expect(items.map((e) => ListResponse.extractId(e)), ['1', '2']);
    });

    test('handles {items: [...]}', () {
      final items = ListResponse.extractItems(
        {
          'items': [
            {'_id': 's1', 'study_name': 'Plant A'},
          ],
          'total': 1,
          'page': 1,
        },
        (json) => json,
      );
      expect(items, hasLength(1));
      expect(ListResponse.extractId(items.first), 's1');
    });

    test('handles DSR studies key', () {
      final items = ListResponse.extractItems(
        {
          'studies': [
            {'study_id': 'd1', 'title': 'DSR 1'},
          ],
          'total': 1,
        },
        (json) => json,
      );
      expect(ListResponse.extractId(items.single, preferredKeys: const ['study_id']), 'd1');
    });

    test('handles LMA lean_maturity_assessments key', () {
      final items = ListResponse.extractItems(
        {
          'lean_maturity_assessments': [
            {'assessment_id': 'a1', 'title': 'LMA 1'},
          ],
        },
        (json) => json,
      );
      expect(
        ListResponse.extractId(items.single, preferredKeys: const ['assessment_id']),
        'a1',
      );
    });
  });

  group('ListResponse.extractId', () {
    test('prefers id then _id then study_id', () {
      expect(ListResponse.extractId({'id': 'a', '_id': 'b'}), 'a');
      expect(ListResponse.extractId({'_id': 'b'}), 'b');
      expect(
        ListResponse.extractId({'study_id': 's1'}, preferredKeys: const ['study_id']),
        's1',
      );
    });

    test('normalizes Mongo ObjectId strings', () {
      expect(
        normalizeEntityId('ObjectId("507f1f77bcf86cd799439011")'),
        '507f1f77bcf86cd799439011',
      );
    });
  });
}
