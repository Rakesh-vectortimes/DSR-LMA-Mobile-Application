import 'package:flutter_test/flutter_test.dart';
import 'package:dsr_lma/features/lma/data/models/lma_config_models.dart';
import 'package:dsr_lma/features/lma/domain/lma_settings.dart';

void main() {
  group('section payloads', () {
    test('create payload zeros counts and sends status 1', () {
      final payload = buildSectionCreatePayload(
        sectionName: '  Quality  ',
        sectionOrder: 2,
      );
      expect(payload.keys.toSet(), {
        'section_name',
        'no_of_questions',
        'total_marks',
        'section_order',
        'status',
      });
      expect(payload['section_name'], 'Quality');
      expect(payload['no_of_questions'], 0);
      expect(payload['total_marks'], 0);
      expect(payload['section_order'], 2);
      expect(payload['status'], 1);
    });

    test('update payload only sends name and order', () {
      final payload = buildSectionUpdatePayload(
        sectionName: 'Leadership',
        sectionOrder: 1,
      );
      expect(payload, {
        'section_name': 'Leadership',
        'section_order': 1,
      });
    });
  });

  group('grade payloads', () {
    test('builds score range and omits 5S fields', () {
      final payload = buildGradePayload(
        gradingCriteria: 'World Class',
        minScore: 81,
        maxScore: 100,
        percentage: 90,
        gradeOrder: 1,
      );
      expect(payload.keys.toSet(), {
        'grading_criteria',
        'score',
        'min_score',
        'max_score',
        'percentage',
        'grade_order',
        'status',
      });
      expect(payload['score'], '81-100');
      expect(payload['status'], 1);
      expect(payload.containsKey('audit_type'), isFalse);
    });
  });

  group('question document payloads', () {
    test('matches LMA document shape without images or 5S trees', () {
      final payload = buildQuestionDocumentPayload(
        fkSectionId: 'sec-1',
        questions: const [
          LmaQuestionItem(
            questionId: 3,
            question: '  How is 5S used?  ',
            options: [
              LmaQuestionOption(score: 5, description: '  Best  '),
              LmaQuestionOption(score: 0, description: 'None'),
            ],
          ),
        ],
      );

      expect(payload.keys.toSet(), {'fk_section_id', 'questions', 'status'});
      expect(payload['fk_section_id'], 'sec-1');
      expect(payload['status'], 1);

      final questions = payload['questions'] as List;
      expect(questions, hasLength(1));
      expect((questions.first as Map).keys.toSet(), {
        'question_id',
        'question',
        'options',
      });
      expect(questions.first['question'], 'How is 5S used?');
      expect(questions.first.containsKey('image'), isFalse);
      expect(questions.first.containsKey('children'), isFalse);

      final options = questions.first['options'] as List;
      expect(options.first['score'], 0);
      expect(options.last['description'], 'Best');
    });
  });

  group('validation', () {
    test('rejects duplicate section name and order', () {
      const others = [
        LmaSection(
          id: 's1',
          sectionName: 'Leadership',
          noOfQuestions: 4,
          totalMarks: 20,
          sectionOrder: 1,
        ),
      ];
      final errors = validateSectionForm(
        sectionName: 'leadership',
        sectionOrder: 1,
        others: others,
      );
      expect(errors.sectionName, 'Section name already exists');
      expect(errors.sectionOrder, 'Order already exists');
    });

    test('rejects overlapping grade ranges', () {
      const others = [
        LmaGrade(
          id: 'g1',
          gradingCriteria: 'Good',
          score: '50-70',
          minScore: 50,
          maxScore: 70,
          percentage: 70,
          gradeOrder: 2,
        ),
      ];
      final errors = validateGradeForm(
        gradingCriteria: 'Better',
        minScore: 60,
        maxScore: 80,
        gradeOrder: 1,
        percentage: 80,
        others: others,
      );
      expect(errors.minScore, contains('overlaps'));
      expect(errors.hasError, isTrue);
    });

    test('rejects duplicate option scores', () {
      final errors = validateQuestionForm(
        fkSectionId: 's1',
        questions: const [
          LmaQuestionItem(
            questionId: 1,
            question: 'Q1',
            options: [
              LmaQuestionOption(score: 1, description: 'A'),
              LmaQuestionOption(score: 1, description: 'B'),
            ],
          ),
        ],
      );
      expect(errors.field('q-0-opt-0-score'), contains('unique'));
      expect(errors.field('q-0-opt-1-score'), contains('unique'));
    });
  });

  group('question id preview', () {
    test('assigns sequential ids by section order', () {
      const sections = [
        LmaSection(
          id: 'b',
          sectionName: 'Quality',
          noOfQuestions: 1,
          totalMarks: 5,
          sectionOrder: 2,
        ),
        LmaSection(
          id: 'a',
          sectionName: 'Leadership',
          noOfQuestions: 2,
          totalMarks: 10,
          sectionOrder: 1,
        ),
      ];
      const documents = [
        LmaQuestionDocument(
          id: 'd1',
          fkSectionId: 'a',
          questions: [
            LmaQuestionItem(questionId: 9, question: 'Old', options: []),
            LmaQuestionItem(questionId: 8, question: 'Old2', options: []),
          ],
        ),
      ];

      final preview = previewQuestionIds(
        sections: sections,
        documents: documents,
        draftSectionId: 'b',
        draftQuestionCount: 1,
      );

      expect(preview['a'], [1, 2]);
      expect(preview['b'], [3]);
    });
  });

  test('grade percentage rounds max / overall * 100', () {
    expect(gradePercentageFromMax(maxScore: 81, overall: 90), 90);
    expect(gradeOverallMaxScore(configMax: 0, grades: const []), 1);
  });

  test('fromJson keeps status and ignores unknown 5S keys', () {
    final section = LmaSection.fromJson(const {
      '_id': 's1',
      'section_name': 'Leadership',
      'no_of_questions': 4,
      'total_marks': 20,
      'section_order': 1,
      'status': 1,
      'audit_types': ['5s'],
      'nested_sections': [],
    });
    expect(section.id, 's1');
    expect(section.status, 1);

    final question = LmaQuestionItem.fromJson(const {
      'question_id': 1,
      'question': 'Q',
      'image': 'http://example/img.png',
      'options': [
        {'score': 0, 'description': 'No'},
      ],
    });
    expect(question.question, 'Q');
    expect(question.toPayload().containsKey('image'), isFalse);
    expect(question.options, hasLength(1));
  });
}
