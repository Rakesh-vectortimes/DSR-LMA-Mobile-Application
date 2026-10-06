import 'package:flutter_test/flutter_test.dart';
import 'package:dsr_lma/features/companies/data/models/company.dart';
import 'package:dsr_lma/features/lma/data/models/lma_config_models.dart';
import 'package:dsr_lma/features/lma/domain/lma_question_mapper.dart';
import 'package:dsr_lma/features/lma/domain/lean_maturity_data.dart';
import 'package:dsr_lma/features/lma/domain/lean_maturity_scoring.dart';

void main() {
  group('CompanyFormValues', () {
    test('create payload defaults currency to INR', () {
      final values = CompanyFormValues(
        companyName: 'Acme',
        location: 'Chennai',
        currency: '',
      );
      final payload = values.toCreatePayload();
      expect(payload['company_name'], 'Acme');
      expect(payload['location'], 'Chennai');
      expect(payload['currency'], 'INR');
      expect(payload['status'], 'active');
      expect(payload['total_workforce'], 1);
    });
  });

  group('mapLmaQuestions', () {
    test('groups by section and dedupes question_id', () {
      const sections = [
        LmaSection(
          id: 's1',
          sectionName: 'Quality Management',
          noOfQuestions: 2,
          totalMarks: 10,
          sectionOrder: 2,
        ),
      ];
      const docs = [
        LmaQuestionDocument(
          id: 'd1',
          fkSectionId: 's1',
          questions: [
            LmaQuestionItem(
              questionId: 6,
              question: 'Q6',
              options: [
                LmaQuestionOption(score: 0, description: 'No'),
                LmaQuestionOption(score: 5, description: 'Yes'),
              ],
            ),
            LmaQuestionItem(
              questionId: 6,
              question: 'Duplicate',
              options: [
                LmaQuestionOption(score: 5, description: 'Yes'),
              ],
            ),
          ],
        ),
      ];

      final questions = mapLmaQuestions(sections: sections, questionDocuments: docs);
      expect(questions, hasLength(1));
      expect(questions.first.id, 6);
      expect(questions.first.category, 'Quality Management');
      expect(questions.first.text, 'Duplicate');
      expect(questions.first.levels.map((l) => l.score), [5]);
    });

    test('falls back to categoryForQuestionId when section missing', () {
      const docs = [
        LmaQuestionDocument(
          id: 'd1',
          fkSectionId: 'missing',
          questions: [
            LmaQuestionItem(
              questionId: 1,
              question: 'Leadership Q1',
              options: [LmaQuestionOption(score: 5, description: 'Yes')],
            ),
          ],
        ),
      ];

      final questions = mapLmaQuestions(sections: const [], questionDocuments: docs);
      expect(questions.single.category, 'Leadership & Strategy');
    });
  });

  group('calculateLeanMaturityScores', () {
    test('score 0 counts as answered and grades by percentage tiers', () {
      const questions = [
        LeanMaturityQuestion(
          id: 1,
          category: 'General',
          text: 'Q1',
          levels: [
            LmaQuestionOption(score: 0, description: 'No'),
            LmaQuestionOption(score: 5, description: 'Yes'),
          ],
        ),
      ];
      const criteria = [
        LmaGradingCriterion(grade: 'C', minScore: 0, maxScore: 2, percentage: 40),
        LmaGradingCriterion(grade: 'A', minScore: 3, maxScore: 5, percentage: 100),
      ];

      final scores = calculateLeanMaturityScores(
        responses: const [
          LeanMaturityResponse(questionId: 1, category: 'General', score: 0),
        ],
        questions: questions,
        gradingCriteria: criteria,
        fullMax: 5,
        categoryMeta: const {
          'General': CategoryScoreMeta(maxScore: 5, totalCount: 1),
        },
      );

      expect(scores.totalScore, 0);
      expect(scores.maxScore, 5);
      expect(scores.percentage, 0);
      expect(scores.grade, 'C');
      expect(scores.answeredCount, 1);
      expect(scores.categoryScores.single.answeredCount, 1);
      expect(isAnsweredScore(0), isTrue);
    });
  });
}
