import '../data/models/lma_config_models.dart';
import 'lean_maturity_data.dart';

class LeanMaturityGradeResult {
  const LeanMaturityGradeResult({
    required this.grade,
    required this.percentage,
    required this.benchmarkPercentage,
  });

  final String grade;
  final int percentage;
  final int benchmarkPercentage;
}

LeanMaturityGradeResult gradeForTotalScore(
  int totalScore,
  int maxScore,
  List<LmaGradingCriterion> gradingCriteria,
) {
  final percentage = maxScore > 0 ? ((totalScore / maxScore) * 100).round() : 0;

  if (gradingCriteria.isEmpty) {
    return LeanMaturityGradeResult(
      grade: 'N/A',
      percentage: percentage,
      benchmarkPercentage: 0,
    );
  }

  final sortedTiers = [...gradingCriteria]
    ..sort((a, b) => a.percentage.compareTo(b.percentage));

  LmaGradingCriterion? tier;
  for (var index = 0; index < sortedTiers.length; index++) {
    final entry = sortedTiers[index];
    final previousThreshold = index == 0 ? -1 : sortedTiers[index - 1].percentage;
    if (percentage <= entry.percentage && percentage > previousThreshold) {
      tier = entry;
      break;
    }
  }
  tier ??= sortedTiers.last;

  return LeanMaturityGradeResult(
    grade: tier.grade,
    percentage: percentage,
    benchmarkPercentage: tier.percentage,
  );
}

Map<String, int> buildResponseScoreMap(List<LeanMaturityResponse>? responses) {
  final responseMap = <String, int>{};
  for (final response in responses ?? const []) {
    if (!isAnsweredScore(response.score)) continue;
    responseMap[leanMaturityQuestionKey(response.questionId)] = response.score!;
  }
  return responseMap;
}

LeanMaturityScores calculateLeanMaturityScores({
  required List<LeanMaturityResponse>? responses,
  required List<LeanMaturityQuestion> questions,
  required List<LmaGradingCriterion> gradingCriteria,
  required int fullMax,
  Map<String, CategoryScoreMeta>? categoryMeta,
}) {
  final responseMap = buildResponseScoreMap(responses);

  final categories = categoryMeta != null
      ? categoryMeta.keys.toList()
      : questions.map((question) => question.category).toSet().toList();

  final categoryScores = categories.map((category) {
    final categoryQuestions = questionsByCategory(questions, category);
    final answeredScores = categoryQuestions
        .map((question) => responseMap[leanMaturityQuestionKey(question.id)])
        .whereType<int>()
        .toList();

    final meta = categoryMeta?[category];
    final fromQuestions = categoryQuestions.isNotEmpty
        ? categoryQuestions.fold(0, (sum, q) => sum + questionMaxScore(q))
        : 0;
    final maxScore = fromQuestions > 0
        ? fromQuestions
        : ((meta?.maxScore ?? 0) > 0
            ? meta!.maxScore
            : categoryQuestions.length * leanMaturityMarksPerQuestion);
    final totalCount = categoryQuestions.isNotEmpty
        ? categoryQuestions.length
        : (meta?.totalCount ?? 0);
    final totalScore = answeredScores.fold(0, (sum, score) => sum + score);
    final gradeResult = gradeForTotalScore(totalScore, maxScore, gradingCriteria);

    return LeanMaturityCategoryScore(
      category: category,
      totalScore: totalScore,
      maxScore: maxScore,
      percentage: gradeResult.percentage,
      grade: gradeResult.grade,
      answeredCount: answeredScores.length,
      totalCount: totalCount,
    );
  }).toList();

  final uniqueQuestions = dedupeQuestionsById(questions);
  final allAnsweredScores = uniqueQuestions
      .map((question) => responseMap[leanMaturityQuestionKey(question.id)])
      .whereType<int>()
      .toList();

  final totalScore = allAnsweredScores.fold(0, (sum, score) => sum + score);
  final questionBankMax =
      uniqueQuestions.fold(0, (sum, question) => sum + questionMaxScore(question));
  final maxScore = fullMax > 0
      ? fullMax
      : questionBankMax > 0
          ? questionBankMax
          : uniqueQuestions.length * leanMaturityMarksPerQuestion;
  final overallGrade = gradeForTotalScore(totalScore, maxScore, gradingCriteria);
  final totalQuestionCount = uniqueQuestions.isNotEmpty
      ? uniqueQuestions.length
      : (categoryMeta?.values.fold<int>(0, (sum, meta) => sum + meta.totalCount) ?? 0);

  return LeanMaturityScores(
    totalScore: totalScore,
    maxScore: maxScore,
    percentage: overallGrade.percentage,
    grade: overallGrade.grade,
    answeredCount: allAnsweredScores.length,
    totalCount: totalQuestionCount,
    categoryScores: categoryScores,
  );
}
