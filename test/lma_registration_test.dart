import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dsr_lma/features/lma_registration/data/models/lma_registration_models.dart';
import 'package:dsr_lma/features/lma_registration/domain/lma_registration_rules.dart';

void main() {
  test('qr url must be an http registration page', () {
    expect(
        isLmaRegistrationQrUrl('http://localhost:4400/Lma-register'), isTrue);
    expect(isLmaRegistrationQrUrl('https://lean.example.com/register'), isTrue);
    expect(
        isLmaRegistrationQrUrl('https://lean.example.com/Lma-register?ref=qr'),
        isTrue);
    expect(
        isLmaRegistrationQrUrl('ftp://lean.example.com/Lma-register'), isFalse);
    expect(isLmaRegistrationQrUrl('https://lean.example.com/home'), isFalse);
    expect(isLmaRegistrationQrUrl('not a url'), isFalse);
  });

  test('saved qr image is the server data url', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final image = 'data:image/png;base64,${base64Encode(bytes)}';
    expect(decodeQrImage(image), bytes);
    expect(decodeQrImage(''), isNull);
  });

  test('public config maps section questions by question number', () {
    final config = parsePublicLmaConfig({
      'sections': [
        {
          'id': 's1',
          'section_name': 'Leadership & Strategy',
          'section_order': 1,
          'no_of_questions': 1,
          'total_marks': 5,
        },
      ],
      'questions': [
        {
          'fk_section_id': 's1',
          'questions': [
            {
              'question_id': 1,
              'question_text': 'How often is strategy reviewed?',
              'options': [
                {'score': 3, 'description': 'Strategy reviewed semi-annually'},
              ],
            },
          ],
        },
      ],
    });

    expect(config.categories, ['Leadership & Strategy']);
    expect(config.questions.single.id, 1);
    expect(config.questions.single.text, 'How often is strategy reviewed?');
  });

  test('submit payload matches the public registration body', () {
    final config = parsePublicLmaConfig({
      'questions': [
        {
          'question_id': 1,
          'category': 'Leadership & Strategy',
          'question': 'How often is strategy reviewed?',
          'options': [
            {'score': 3, 'description': 'Strategy reviewed semi-annually'},
          ],
        },
      ],
    });

    final payload = buildLmaRegistrationPayload(
      companyName: 'sdcz',
      clientName: 'Rakesh Anandan',
      clientEmail: 'codeurrakesh17@gmail.com',
      title: '',
      reportDate: '2026-11-03',
      companyIntroduction: 'sdz',
      location: 'daf',
      totalWorkforce: 2,
      shiftOperation: '3',
      workingHours: '3',
      workingDays: '5',
      questions: config.questions,
      scores: const {1: 3},
    );

    expect(payload['company_name'], 'sdcz');
    expect(payload['title'], 'sdcz Lean Maturity Assessment');
    expect(payload['client_email'], 'codeurrakesh17@gmail.com');
    final responses = payload['assessment']['details']['responses'] as List;
    expect(responses.single, {
      'question_id': 1,
      'score': 3,
      'selected_response': 'Strategy reviewed semi-annually',
    });
    expect(isRegistrationEmail('codeurrakesh17@gmail.com'), isTrue);
    expect(isRegistrationEmail('not-an-email'), isFalse);
  });

  test('email result explains a saved registration when mail fails', () {
    expect(
      lmaRegistrationEmailMessage(
        emailSent: true,
        email: 'a@b.com',
        emailError: null,
      ),
      contains('emailed the assessment PDF'),
    );
    expect(
      lmaRegistrationEmailMessage(
        emailSent: false,
        email: 'a@b.com',
        emailError: 'smtp_not_configured',
      ),
      contains('not configured'),
    );
  });

  test('registration list row keeps the integer status', () {
    final row = LmaRegistrationSummary.fromJson({
      'id': 'reg-1',
      'company_name': 'sdcz',
      'client_name': 'Rakesh Anandan',
      'client_email': 'codeurrakesh17@gmail.com',
      'status': 1,
      'status_label': 'Waiting for approval',
      'created_on': '2026-11-03T10:00:00Z',
    });

    expect(row.canApprove, isTrue);
    expect(row.status, LmaRegistrationStatus.waiting);
    expect(row.statusLabel, 'Waiting for approval');

    final approved = LmaRegistrationSummary.fromJson({
      ...{
        'id': 'reg-1',
        'company_name': 'sdcz',
        'status': 2,
      },
    });
    expect(approved.canApprove, isFalse);
  });
}
