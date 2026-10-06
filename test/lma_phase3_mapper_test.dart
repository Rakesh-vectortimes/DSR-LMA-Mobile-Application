import 'package:flutter_test/flutter_test.dart';

import 'package:dsr_lma/core/constants/report_status.dart';
import 'package:dsr_lma/features/companies/data/models/company.dart';
import 'package:dsr_lma/features/lma/data/models/lma_config_models.dart';
import 'package:dsr_lma/features/lma/domain/lma_api_mapper.dart';

void main() {
  test('buildLmaApiPayload maps submitted to published int and includes response text', () {
    final payload = buildLmaApiPayload(
      company: CompanyFormValues(
        companyId: 'cmp-1',
        companyName: 'Acme',
        location: 'Chennai',
        companyIntroduction: 'Intro',
        totalWorkforce: 120,
        shiftOperation: 2,
        workingHours: '8',
        workingDays: 6,
        currency: 'INR',
        currencySymbol: 'Rs',
      ),
      responses: const [
        LeanMaturityResponse(
          questionId: 1,
          category: 'Leadership & Strategy',
          score: 4,
        ),
      ],
      questions: const [
        LeanMaturityQuestion(
          id: 1,
          category: 'Leadership & Strategy',
          text: 'Question 1',
          levels: [
            LmaQuestionOption(score: 4, description: 'Advanced'),
          ],
        ),
      ],
      status: 'submitted',
      reportDate: DateTime(2026, 8, 17),
    );

    expect(payload['status'], 2);
    expect(payload['title'], 'Acme Lean Maturity Assessment');
    expect(payload['report_date'], '2026-08-17');

    final companyBackground =
        payload['company_background'] as Map<String, dynamic>;
    final details = companyBackground['details'] as Map<String, dynamic>;
    expect(details['company_name'], 'Acme');
    expect(details['total_workforce'], 120);

    final assessment = payload['assessment'] as Map<String, dynamic>;
    final assessmentDetails = assessment['details'] as Map<String, dynamic>;
    final responses = assessmentDetails['responses'] as List<dynamic>;
    final first = responses.first as Map<String, dynamic>;
    expect(first['selected_response'], 'Advanced');
  });

  test('normalizeLmaRecord prefers created_by_name and hides object ids', () {
    final record = normalizeLmaRecord({
      '_id': '507f1f77bcf86cd799439011',
      'company_name': 'Acme',
      'report_date': '2026-08-17T00:00:00.000Z',
      'status': 'published',
      'created_by_name': 'Jane Doe',
      'updated_by': '507f1f77bcf86cd799439012',
      'company_background': {
        'details': {
          'company_id': 'cmp-1',
          'company_name': 'Acme',
          'location': 'Chennai',
        },
      },
      'assessment': {
        'details': {
          'responses': [
            {
              'question_id': 1,
              'category': 'Leadership & Strategy',
              'score': 5,
              'question': 'Question 1',
              'selected_response': 'Expert',
            },
          ],
        },
      },
    });

    expect(record.id, '507f1f77bcf86cd799439011');
    expect(record.preparedBy, 'Jane Doe');
    expect(record.updatedBy, isNull);
    expect(record.reportDate, '2026-08-17');
    expect(record.status, 2);
    expect(record.displayStatus, 'Published');
    expect(record.responses.single.selectedResponse, 'Expert');
  });

  test('parses integer status and submitted alias', () {
    expect(ReportStatus.parse('published'), ReportStatus.published);
    expect(ReportStatus.parse('submitted'), ReportStatus.published);
    expect(ReportStatus.parse('draft'), ReportStatus.draft);
    expect(ReportStatus.parse('archived'), ReportStatus.archived);
  });

  test('lmaRecordToFormPatch keeps published as integer 2', () {
    final patch = lmaRecordToFormPatch(
      normalizeLmaRecord({
        'id': 'a1',
        'status': 2,
        'status_label': 'Published',
        'company_background': {'details': {'company_name': 'Acme'}},
        'assessment': {'details': {'responses': []}},
      }),
    );
    expect(patch['status'], 2);
  });
}
