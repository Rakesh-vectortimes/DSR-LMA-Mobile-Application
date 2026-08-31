import '../data/models/lma_config_models.dart';
import 'lean_maturity_data.dart';

List<LeanMaturityQuestion> mapLmaQuestions({
  required List<LmaSection> sections,
  required List<LmaQuestionDocument> questionDocuments,
}) {
  final sectionNameById = {
    for (final section in sections) section.id: section.sectionName,
  };
  final questionById = <int, LeanMaturityQuestion>{};

  for (final doc in questionDocuments) {
    final sectionCategory = sectionNameById[doc.fkSectionId] ?? '';
    for (final item in doc.questions) {
      if (item.questionId <= 0) continue;
      final category =
          sectionCategory.isNotEmpty ? sectionCategory : categoryForQuestionId(item.questionId);
      final sortedOptions = [...item.options]
        ..sort((a, b) => a.score.compareTo(b.score));

      questionById[item.questionId] = LeanMaturityQuestion(
        id: item.questionId,
        category: category,
        text: item.question,
        levels: sortedOptions,
      );
    }
  }

  return dedupeQuestionsById(questionById.values.toList());
}

List<LmaGradingCriterion> mapGradingCriteria(List<LmaGrade> grades) {
  final sorted = [...grades]
    ..sort((a, b) => (a.gradeOrder ?? 0).compareTo(b.gradeOrder ?? 0));
  return sorted
      .map(
        (grade) => LmaGradingCriterion(
          grade: grade.gradingCriteria,
          minScore: grade.minScore,
          maxScore: grade.maxScore,
          percentage: grade.percentage,
        ),
      )
      .toList();
}

Map<String, CategoryScoreMeta> buildCategoryMeta({
  required List<LmaSection> sections,
  required List<LeanMaturityQuestion> questions,
}) {
  final meta = <String, CategoryScoreMeta>{};

  for (final section in [...sections]
    ..sort((a, b) => (a.sectionOrder ?? 0).compareTo(b.sectionOrder ?? 0))) {
    final categoryQuestions = questionsByCategory(questions, section.sectionName);
    final maxScore = categoryQuestions.isNotEmpty
        ? categoryQuestions.fold(0, (sum, q) => sum + questionMaxScore(q))
        : (section.totalMarks > 0
            ? section.totalMarks
            : (section.noOfQuestions > 0
                ? section.noOfQuestions * leanMaturityMarksPerQuestion
                : 0));
    final totalCount =
        categoryQuestions.isNotEmpty ? categoryQuestions.length : section.noOfQuestions;

    meta[section.sectionName] = CategoryScoreMeta(
      maxScore: maxScore,
      totalCount: totalCount,
    );
  }

  for (final question in questions) {
    if (meta.containsKey(question.category)) continue;
    final loaded = questionsByCategory(questions, question.category);
    meta[question.category] = CategoryScoreMeta(
      maxScore: loaded.fold(0, (sum, q) => sum + questionMaxScore(q)),
      totalCount: loaded.length,
    );
  }

  return meta;
}

int resolveOverallMaxScore({
  required List<LmaSection> sections,
  required List<LeanMaturityQuestion> questions,
}) {
  if (questions.isNotEmpty) {
    final total = questionsMaxScoreTotal(questions);
    if (total > 0) return total;
  }

  if (sections.isNotEmpty) {
    final total = sections.fold<int>(0, (sum, section) {
      if (section.totalMarks > 0) return sum + section.totalMarks;
      if (section.noOfQuestions > 0) {
        return sum + section.noOfQuestions * leanMaturityMarksPerQuestion;
      }
      return sum;
    });
    if (total > 0) return total;
  }

  return questions.length * leanMaturityMarksPerQuestion;
}

List<String> orderedCategories({
  required List<LmaSection> sections,
  required List<LeanMaturityQuestion> questions,
}) {
  if (sections.isNotEmpty) {
    final sorted = [...sections]
      ..sort((a, b) => (a.sectionOrder ?? 0).compareTo(b.sectionOrder ?? 0));
    return sorted
        .map((section) => section.sectionName)
        .where((name) => name.isNotEmpty)
        .toList();
  }

  final seen = <String>{};
  final ordered = <String>[];
  for (final question in questions) {
    if (question.category.isEmpty || seen.contains(question.category)) continue;
    seen.add(question.category);
    ordered.add(question.category);
  }
  return ordered;
}
